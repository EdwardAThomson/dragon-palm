// Layer 1: the assembler. Reassembles the bundled carts to byte-identical
// images and checks syntax/number/error handling.
const {test}=require('node:test')
const assert=require('node:assert/strict')
const fs=require('node:fs'),path=require('node:path')
const {assemble,ROOT}=require('./harness.js')

const CARTS=['adder','magic-screen','tennis']

for(const name of CARTS){
  test(`assembles ${name}.asm byte-identical to committed ${name}.dgc`,()=>{
    const src=fs.readFileSync(path.join(ROOT,'carts',`${name}.asm`),'utf8')
    const committed=new Uint8Array(fs.readFileSync(path.join(ROOT,'carts',`${name}.dgc`)))
    assert.deepEqual(assemble(src,name),committed)
  })
}

test('output is always padded to exactly 8192 bytes',()=>{
  assert.equal(assemble('NOP').length,8192)
  assert.equal(assemble('LD_A 1\nDRW').length,8192)
})

test('number bases all parse to the same value',()=>{
  // $40, 0x40, %1000000, 64 are all 64 -> LD_A operand byte
  for(const lit of ['$40','0x40','%1000000','64'])
    assert.equal(assemble(`LD_A ${lit}`)[1],64,`literal ${lit}`)
  assert.equal(assemble("LD_A 'A'")[1],65,'char literal')
})

test('EQU defines a constant usable as an operand',()=>{
  assert.deepEqual([...assemble('SPEED EQU 7\nLD_A SPEED').slice(0,2)],[1,7])
})

test('DB and DW emit bytes and little-endian words',()=>{
  assert.deepEqual([...assemble('DB 1, 2, 3').slice(0,3)],[1,2,3])
  assert.deepEqual([...assemble('DW $2000').slice(0,2)],[0x00,0x20])
})

test('label arithmetic resolves (label+1 for self-modifying code)',()=>{
  // LD_A [here+1] -> opcode 2, then little-endian (here+1). here=0 so operand=1.
  assert.deepEqual([...assemble('here:\n  LD_A [here+1]').slice(0,3)],[2,1,0])
})

test('spaces inside [...] are a hard error (tokenizer splits on whitespace)',()=>{
  assert.throws(()=>assemble('STA [foo + 1]'),/unknown symbol/)
})

test('program exceeding 8192 bytes is rejected',()=>{
  // 8193 NOPs -> one byte past the ceiling.
  assert.throws(()=>assemble('NOP\n'.repeat(8193)),/exceeds 8192/)
})

test('unknown instruction and unknown symbol are reported with line numbers',()=>{
  assert.throws(()=>assemble('FOO 1'),/:1: unknown instruction "FOO"/)
  assert.throws(()=>assemble('LD_A missing'),/:1: unknown symbol "missing"/)
})
