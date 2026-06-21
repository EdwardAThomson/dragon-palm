// Layer 3: cart functionality. Loads a real .dgc, feeds scripted input, runs
// frames, and asserts on the resulting screen — "does the game work?".
// Also pins golden VRAM hashes as a regression net for the whole pipeline.
const {test}=require('node:test')
const assert=require('node:assert/strict')
const {loadCartFile,run,pixelAt,vramHash}=require('./harness.js')

// Button bitmasks (see docs/hardware.md).
const UP=1,RIGHT=8,U=16

test('magic-screen: paints the start pixel and changes colour on U',()=>{
  // No input: cursor stays at (64,64) and paints its colour (11).
  assert.equal(pixelAt(run(loadCartFile('magic-screen.dgc'),3,0),64,64),11)
  // Hold U: cursor stays put but the painted colour changes away from 11.
  const u=run(loadCartFile('magic-screen.dgc'),4,U)
  assert.notEqual(pixelAt(u,64,64),11)
})

test('magic-screen: D-pad moves the cursor (Right paints to the right)',()=>{
  // Input is applied before the first paint, so the cursor steps to x=65 and
  // paints there; (64,64) is never painted and nothing appears above the row.
  const r=run(loadCartFile('magic-screen.dgc'),6,RIGHT)
  assert.equal(pixelAt(r,65,64),11)
  assert.equal(pixelAt(r,64,63),0)
})

test('adder: snake head and stationary treat are on screen',()=>{
  const a=run(loadCartFile('adder.dgc'),3,0)
  assert.equal(pixelAt(a,96,64),14,'treat (colour 14) at its start position')
  assert.equal(pixelAt(a,65,64),12,'head (colour 12) advanced one step right')
})

test('tennis: draws the initial board',()=>{
  const t=run(loadCartFile('tennis.dgc'),5,0)
  assert.equal(pixelAt(t,64,64),15,'ball at centre')
  for(const y of [24,48,72,96])assert.equal(pixelAt(t,64,y),5,`net dot at y=${y}`)
  for(const y of [61,62,63,64,65,66])assert.equal(pixelAt(t,8,y),6,`player paddle at y=${y}`)
})

test('tennis: player paddle responds to Up',()=>{
  // Baseline: with no input the paddle stays, so its bottom pixel is still set.
  assert.equal(pixelAt(run(loadCartFile('tennis.dgc'),5,0),8,66),6)
  // Holding Up vacates the old bottom row and fills a row above the start.
  const up=run(loadCartFile('tennis.dgc'),5,UP)
  assert.equal(pixelAt(up,8,66),0,'old bottom vacated')
  assert.equal(pixelAt(up,8,60),6,'paddle moved up')
})

// Golden VRAM fingerprints: 30 frames, no input. These pin the exact output of
// the assembler+core pipeline; a change to either breaks them on purpose.
const GOLDEN={adder:'cf197c4e','magic-screen':'186d0675',tennis:'5c4be430'}
for(const [name,hash] of Object.entries(GOLDEN)){
  test(`golden screen unchanged: ${name}`,()=>{
    assert.equal(vramHash(run(loadCartFile(`${name}.dgc`),30,0)),hash)
  })
}
