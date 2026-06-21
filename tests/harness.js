// Shared test helpers for driving the Dragon Palm core headlessly.
// No browser, no DOM — just the same core that index.html ships.
const fs=require('node:fs'),path=require('node:path')
const {DragonPalmCore}=require('../tools/core.js')
const {assemble}=require('../tools/assembler.js')

const ROOT=path.join(__dirname,'..')
const VRAM=8192 // $2000

// Load an 8192-byte cart image into a fresh core, mirroring index.html's cold():
// zero RAM, copy cart to $0000, reset registers, boot screen off (a cart is present).
function loadCart(bytes){
  const c=new DragonPalmCore()
  c.RAM.fill(0)
  c.RAM.set(bytes,0)
  c.A=c.X=c.Y=c.PC=0
  c.boot=0
  return c
}

// Load a cart straight from a carts/NAME.dgc file.
function loadCartFile(name){
  return loadCart(new Uint8Array(fs.readFileSync(path.join(ROOT,'carts',name))))
}

// Run `frames` frames. `input` is either a constant button bitmask or a
// function(frameIndex) => bitmask, written into the input register before each frame.
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

// Stable hash of the whole 8 KB VRAM region — used as a golden screen fingerprint.
function vramHash(core){
  let h=0x811c9dc5
  for(let i=VRAM;i<16384;i++){h^=core.RAM[i];h=Math.imul(h,0x01000193)>>>0}
  return h.toString(16).padStart(8,'0')
}

module.exports={loadCart,loadCartFile,run,pixelAt,vramHash,assemble,DragonPalmCore,ROOT}
