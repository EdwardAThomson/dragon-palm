#!/usr/bin/env node
const fs=require('node:fs'),path=require('node:path')

// Assemble Dragon Palm source text into an 8192-byte cartridge image.
// Throws Error(`${name}:${line}: ${message}`) on any problem. `name` is only
// used to label errors (defaults to "input").
function assemble(text,name='input'){
  const src=text.replace(/\r/g,'').split('\n')
  const labels={},consts={}
  const clean=s=>s.replace(/;.*/,'').trim()
  const fail=(n,m)=>{throw Error(`${name}:${n}: ${m}`)}
  const parts=s=>s.replace(/,/g,' ').trim().split(/\s+/).filter(Boolean)
  const unbox=s=>s?.startsWith('[')&&s.endsWith(']')?s.slice(1,-1):s
  const term=(s,n)=>{
    s=s.trim()
    if(/^'.'$/.test(s))return s.charCodeAt(1)
    if(/^\$[0-9a-f]+$/i.test(s))return parseInt(s.slice(1),16)
    if(/^0x[0-9a-f]+$/i.test(s))return parseInt(s,16)
    if(/^%[01]+$/.test(s))return parseInt(s.slice(1),2)
    if(/^-?\d+$/.test(s))return +s
    if(s in labels)return labels[s]
    if(s in consts)return consts[s]
    fail(n,`unknown symbol "${s}"`)
  }
  const val=(s,n)=>{
    s=unbox(s).replace(/\s+/g,'')
    let t=s.match(/[+-]?[^+-]+/g),v=0
    if(!t)fail(n,'missing value')
    for(let p of t){
      let m=p[0]=='-'?-1:1
      if(p[0]=='+'||p[0]=='-')p=p.slice(1)
      v+=m*term(p,n)
    }
    return v
  }
  const size=(t,n)=>{
    let o=t[0].toUpperCase(),a=t[1]
    if(!o)return 0
    if(o=='EQU')fail(n,'EQU needs a name before it')
    if(o=='DB'||o=='.BYTE')return t.length-1
    if(o=='DW'||o=='.WORD')return (t.length-1)*2
    if(o=='ORG'||o=='.ORG')return 0
    if(o=='NOP'||o=='ADD_A'||o=='SUB_A'||o=='DRW'||o=='RDIN')return 1
    if(o=='LD_X'||o=='LD_Y')return 2
    if(o=='JMP'||o=='JNZ'||o=='STA')return 3
    if(o=='LD_A')return a?.startsWith('[')?3:2
    fail(n,`unknown instruction "${o}"`)
  }
  const scan=emit=>{
    let pc=0,out=emit&&new Uint8Array(8192)
    const byte=(v,n)=>{if(pc>8191)fail(n,'program exceeds 8192 bytes');if(emit)out[pc]=v&255;pc++}
    const word=(v,n)=>{byte(v,n);byte(v>>8,n)}
    for(let i=0;i<src.length;i++){
      let line=clean(src[i]),m
      while((m=line.match(/^([A-Za-z_][\w.]*)\s*:\s*/))){
        if(!emit)labels[m[1]]=pc
        line=line.slice(m[0].length).trim()
      }
      if(!line)continue
      let t=parts(line),o=t[0].toUpperCase(),name=t[0]
      if(t[1]?.toUpperCase()=='EQU'){
        if(!emit)consts[name]=val(t.slice(2).join(''),i+1)
        continue
      }
      if(o=='ORG'||o=='.ORG'){pc=val(t[1],i+1);continue}
      if(!emit){pc+=size(t,i+1);continue}
      switch(o){
        case 'DB':case '.BYTE':for(let p of t.slice(1))byte(val(p,i+1),i+1);break
        case 'DW':case '.WORD':for(let p of t.slice(1))word(val(p,i+1),i+1);break
        case 'NOP':byte(0,i+1);break
        case 'LD_A':
          if(t[1]?.startsWith('[')){byte(2,i+1);word(val(t[1],i+1),i+1)}
          else{byte(1,i+1);byte(val(t[1],i+1),i+1)}
          break
        case 'STA':byte(3,i+1);word(val(t[1],i+1),i+1);break
        case 'ADD_A':byte(4,i+1);break
        case 'SUB_A':byte(5,i+1);break
        case 'JMP':byte(6,i+1);word(val(t[1],i+1),i+1);break
        case 'JNZ':byte(7,i+1);word(val(t[1],i+1),i+1);break
        case 'DRW':byte(8,i+1);break
        case 'RDIN':byte(9,i+1);break
        case 'LD_X':byte(10,i+1);byte(val(t[1],i+1),i+1);break
        case 'LD_Y':byte(11,i+1);byte(val(t[1],i+1),i+1);break
        default:fail(i+1,`unknown instruction "${o}"`)
      }
    }
    return out
  }
  scan(0)
  return scan(1)
}

if(require.main===module){
  const [, , input, output]=process.argv
  if(!input){
    console.error('Usage: node tools/assembler.js input.asm [output.dgc]')
    process.exit(1)
  }
  const cart=assemble(fs.readFileSync(input,'utf8'),input)
  const outFile=output||input.replace(/\.[^.]+$/,'.dgc')
  fs.mkdirSync(path.dirname(outFile),{recursive:true})
  fs.writeFileSync(outFile,cart)
  console.log(`Wrote ${outFile} (${cart.length} bytes)`)
}

module.exports={assemble}
