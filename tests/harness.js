// Shared test helpers for driving the Dragon Palm core headlessly.
//
// These tests CHARACTERISE the existing repo without modifying any source: the
// emulator core is extracted from index.html as-is, and the assembler is run as
// a black-box subprocess. (The assembler self-executes on import and would exit
// the test runner, so it cannot be require()d; the core class has no DOM
// dependencies, so it evaluates fine outside a browser.)
const fs=require('node:fs'),path=require('node:path'),os=require('node:os')
const {execFileSync}=require('node:child_process')

const ROOT=path.join(__dirname,'..')
const VRAM=8192 // $2000

// Pull the shipping DragonPalmCore class out of index.html and evaluate it.
function loadCoreClass(){
  const html=fs.readFileSync(path.join(ROOT,'index.html'),'utf8')
  const m=html.match(/class DragonPalmCore\{[\s\S]*?\n\}/)
  if(!m)throw new Error('could not locate DragonPalmCore class in index.html')
  return new Function(m[0]+';return DragonPalmCore')()
}
const DragonPalmCore=loadCoreClass()

// Assemble source by invoking the real CLI (tools/assembler.js) as a subprocess.
// Returns the 8192-byte image; throws with the assembler's stderr on failure,
// matching its `name:line: message` format.
const TMP=fs.mkdtempSync(path.join(os.tmpdir(),'dgc-'))
let seq=0
function assemble(text,name='input'){
  const base=path.join(TMP,`u${seq++}`)
  const inF=base+'.asm',outF=base+'.dgc'
  fs.writeFileSync(inF,text)
  try{
    execFileSync(process.execPath,[path.join(ROOT,'tools','assembler.js'),inF,outF],
      {stdio:['ignore','ignore','pipe']})
  }catch(e){
    throw new Error(e.stderr?e.stderr.toString():String(e))
  }
  return new Uint8Array(fs.readFileSync(outF))
}

// Load an 8192-byte cart image into a fresh core, mirroring index.html's cold():
// zero RAM, copy cart to $0000, reset registers, boot screen off.
function loadCart(bytes){
  const c=new DragonPalmCore()
  c.RAM.fill(0)
  c.RAM.set(bytes,0)
  c.A=c.X=c.Y=c.PC=0
  c.boot=0
  return c
}

function loadCartFile(name){
  return loadCart(new Uint8Array(fs.readFileSync(path.join(ROOT,'carts',name))))
}

// Run `frames` frames. `input` is a constant button bitmask or a
// function(frameIndex) => bitmask, written to the input register before each frame.
function run(core,frames,input=0){
  for(let f=0;f<frames;f++){
    core.input=typeof input==='function'?input(f):input
    core.frame()
  }
  return core
}

// Decode one pixel's 4-bit colour from packed VRAM (even x = high nibble, odd = low).
function pixelAt(core,x,y){
  const b=core.RAM[VRAM+((y*128+x)>>1)]
  return (x&1)?(b&15):(b>>4)
}

// Stable hash of the whole 8 KB VRAM region — a golden screen fingerprint.
function vramHash(core){
  let h=0x811c9dc5
  for(let i=VRAM;i<16384;i++){h^=core.RAM[i];h=Math.imul(h,0x01000193)>>>0}
  return h.toString(16).padStart(8,'0')
}

module.exports={loadCart,loadCartFile,run,pixelAt,vramHash,assemble,DragonPalmCore,ROOT}
