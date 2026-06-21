// Fidelity guard: proves the headless test harness exercises the SAME behaviour
// that ships in index.html, so "the suite is green" means "the browser is right".
//
// It does this by extracting index.html's own host logic (cart loading, palette,
// pixel decode) and running it head-to-head against the harness, and by checking
// the in-process assembler matches the CLI. If anyone later edits index.html's
// load/render code, or lets the core/harness drift, these tests fail.
const {test}=require('node:test')
const assert=require('node:assert/strict')
const fs=require('node:fs'),path=require('node:path'),os=require('node:os')
const {execFileSync}=require('node:child_process')
const {DragonPalmCore,loadCart,pixelAt,assemble,ROOT}=require('./harness.js')

const html=fs.readFileSync(path.join(ROOT,'index.html'),'utf8')

// Deterministic RNG so the proof is reproducible across runs and machines.
function rng(seed){return n=>((seed=(Math.imul(seed,1103515245)+12345)&0x7fffffff)>>>0)%n}

test('index.html loads the shared core (no divergent inline copy)',()=>{
  assert.match(html,/<script src="tools\/core\.js">/,'must load tools/core.js')
  assert.doesNotMatch(html,/class DragonPalmCore\{/,'must not re-inline the class')
})

test("harness loadCart() reproduces index.html's cold()",()=>{
  // Run index.html's actual cold() body against a core, compare to loadCart().
  const coldBody=html.match(/let cold=\(\)=>\{(.*)\}\r?\nlet key/)[1]
  const cold=new Function('C','cart',coldBody)
  const rnd=rng(0x1234567)
  for(let t=0;t<100;t++){
    const cart=new Uint8Array(8192).map(()=>rnd(256))
    const browser=new DragonPalmCore();cold(browser,cart)
    const harness=loadCart(cart)
    assert.deepEqual(harness.RAM,browser.RAM,`RAM (iter ${t})`)
    assert.equal(harness.A,browser.A)
    assert.equal(harness.X,browser.X)
    assert.equal(harness.Y,browser.Y)
    assert.equal(harness.PC,browser.PC)
    assert.equal(harness.input,browser.input)
    assert.equal(Boolean(harness.boot),Boolean(browser.boot)) // false and 0 are the same falsy state
  }
})

test("harness pixelAt()+palette reproduces index.html's render",()=>{
  // Run index.html's actual decode loop, compare every pixel to pixelAt()+palette.
  const P=eval(html.match(/new Uint32Array\(\[0xff000000[^\]]*\]\)/)[0])
  const decode=new Function('C','D','P',html.match(/for\(let i=8192,j=0;i<16384;i\+\+\)\{[\s\S]*?\}/)[0])
  const rnd=rng(0x55aa55)
  for(let t=0;t<30;t++){
    const c=new DragonPalmCore()
    for(let i=8192;i<16384;i++)c.RAM[i]=rnd(256)
    const D=new Uint32Array(128*128);decode(c,D,P)
    for(let y=0;y<128;y++)for(let x=0;x<128;x++)
      assert.equal(D[y*128+x],P[pixelAt(c,x,y)],`pixel ${x},${y} (iter ${t})`)
  }
})

test('in-process assemble() matches the assembler CLI (bytes and errors)',()=>{
  const TMP=fs.mkdtempSync(path.join(os.tmpdir(),'dgcfid-'))
  const CLI=path.join(ROOT,'tools','assembler.js')
  const key=s=>{const m=s.match(/:(\d+): (.+)/);return m?`${m[1]}|${m[2].trim()}`:null}
  let i=0
  const viaCLI=src=>{
    const a=path.join(TMP,`f${i}.asm`),o=path.join(TMP,`f${i++}.dgc`)
    fs.writeFileSync(a,src)
    try{execFileSync(process.execPath,[CLI,a,o],{stdio:['ignore','ignore','pipe']})}
    catch(e){return {err:key((e.stderr||'').toString())}}
    return {bytes:new Uint8Array(fs.readFileSync(o))}
  }
  const viaFn=src=>{try{return {bytes:assemble(src,'x')}}catch(e){return {err:key(e.message)}}}

  const rnd=rng(0xc0ffee)
  const labels=()=>{const ls=['start'];const out=['start:']
    for(let k=0;k<8+rnd(20);k++){const r=rnd(9)
      if(r===0){const L='L'+k;ls.push(L);out.push(L+':')}
      else if(r===1)out.push('LD_A '+rnd(256))
      else if(r===2)out.push('LD_X '+rnd(256))
      else if(r===3)out.push('STA ['+ls[rnd(ls.length)]+'+1]')
      else if(r===4)out.push('JMP '+ls[rnd(ls.length)])
      else if(r===5)out.push('JNZ '+ls[rnd(ls.length)])
      else if(r===6)out.push('DB '+rnd(256)+', '+rnd(256))
      else if(r===7)out.push('LD_A [$'+rnd(16384).toString(16)+']')
      else out.push(['NOP','ADD_A','SUB_A','DRW','RDIN'][rnd(5)])}
    return out.join('\n')}

  const carts=['adder','magic-screen','tennis'].map(n=>fs.readFileSync(path.join(ROOT,'carts',n+'.asm'),'utf8'))
  const invalid=['STA [foo + 1]','FOO 1','LD_A missing','NOP\n'.repeat(8200)]
  const corpus=[...carts,...invalid,...Array.from({length:30},labels)]

  for(const src of corpus){
    const a=viaCLI(src),b=viaFn(src)
    if(a.bytes&&b.bytes)assert.deepEqual(b.bytes,a.bytes,'bytes differ')
    else{assert.ok(a.err&&b.err,'one path errored but not the other')
      assert.equal(b.err,a.err,'error mismatch')}
  }
})
