// Layer 2: the CPU / ISA. Drives the shared core directly, one opcode at a time.
const {test}=require('node:test')
const assert=require('node:assert/strict')
const {DragonPalmCore,pixelAt}=require('./harness.js')

// Fresh core with `bytes` loaded at $0000, boot screen off.
function cpu(bytes=[]){const c=new DragonPalmCore();c.RAM.set(bytes,0);c.boot=0;return c}

test('LD_A / LD_X / LD_Y load immediates',()=>{
  const c=cpu([1,42, 10,7, 11,9]) // LD_A 42; LD_X 7; LD_Y 9
  c.step();assert.equal(c.A,42)
  c.step();assert.equal(c.X,7)
  c.step();assert.equal(c.Y,9)
})

test('ADD_A wraps at 255',()=>{
  const c=cpu([4]);c.A=200;c.X=100;c.step()
  assert.equal(c.A,44) // (200+100)&255
})

test('SUB_A wraps below 0',()=>{
  const c=cpu([5]);c.A=5;c.X=10;c.step()
  assert.equal(c.A,251) // (5-10)&255
})

test('JNZ jumps when A != 0, falls through when A == 0',()=>{
  const taken=cpu([7,0x10,0x00]);taken.A=1;taken.step()
  assert.equal(taken.PC,0x10)
  const fall=cpu([7,0x10,0x00]);fall.A=0;fall.step()
  assert.equal(fall.PC,3) // past the 3-byte instruction
})

test('JMP sets PC (masked into program space)',()=>{
  const c=cpu([6,0x34,0x12]);c.step()
  assert.equal(c.PC,0x1234&8191)
})

test('STA writes below $4000 and is ignored at/above it',()=>{
  const c=cpu([3,0xFF,0x3F]);c.A=99;c.step() // STA [$3FFF]
  assert.equal(c.RAM[0x3FFF],99)
  const before=Uint8Array.from(c.RAM)
  const d=cpu([3,0x00,0x40]);d.A=99 // STA [$4000] -> ignored
  d.RAM.set(before) // observable region snapshot
  const snap=Uint8Array.from(d.RAM)
  d.step()
  assert.deepEqual(d.RAM,snap,'no observable RAM change')
})

test('LD_A [$4000] reads the input register, other addresses read RAM',()=>{
  const c=cpu([2,0x00,0x40]);c.input=42;c.step() // LD_A [$4000]
  assert.equal(c.A,42)
  const d=cpu([2,0x05,0x00]);d.RAM[5]=77;d.step() // LD_A [$0005]
  assert.equal(d.A,77)
})

test('RDIN loads the input bitmask into A',()=>{
  const c=cpu([9]);c.input=0xA5;c.step()
  assert.equal(c.A,0xA5)
})

test('DRW packs even x to high nibble, odd x to low nibble',()=>{
  const c=cpu([8]);c.X=2;c.Y=0;c.A=5;c.step() // even x
  assert.equal(pixelAt(c,2,0),5)
  const d=cpu([8]);d.X=3;d.Y=0;d.A=6;d.step() // odd x, same byte
  assert.equal(pixelAt(d,3,0),6)
})

test('DRW uses only the low nibble of A',()=>{
  const c=cpu([8]);c.X=0;c.Y=0;c.A=0xFF;c.step()
  assert.equal(pixelAt(c,0,0),15)
})

test('DRW rejects coordinates outside 0-127',()=>{
  const c=cpu([8]);c.X=200;c.Y=0;c.A=5;c.step()
  for(let i=8192;i<16384;i++)assert.equal(c.RAM[i],0,'VRAM untouched')
})

test('PC wraps inside the 8 KB program space',()=>{
  const c=cpu();c.PC=8191;c.RAM[8191]=0;c.step() // NOP at the last byte
  assert.equal(c.PC,0)
})
