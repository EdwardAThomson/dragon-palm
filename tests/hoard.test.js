// Dragon Hoard — functional tests for the demo cart.
//
// The dragon is an 8-pixel green (11) sprite; the gem is a 3x3 lavender (14)
// block; a caught gem lights a white (7) score pip. Movement erases+redraws the
// sprite, so a frame can be sampled mid-redraw — tests therefore assert
// invariants that survive that (e.g. "never more than 8 green pixels"), and read
// the base coordinate from RAM for exact collision checks.
const {test}=require('node:test')
const assert=require('node:assert/strict')
const {loadCartFile,run,pixelAt}=require('./harness.js')

const UP=1,RIGHT=8
const DRAGON=11,GEM=14,PIP=7

const count=(c,col)=>{let n=0;for(let i=8192;i<16384;i++){if((c.RAM[i]>>4)===col)n++;if((c.RAM[i]&15)===col)n++}return n}
// Locate the base coordinate (bx,by) in program RAM via the initial data block
// bx,by,gemx,gemy,col,gcol = 64,64,94,62,11,14.
function baseAddr(c){
  for(let i=0;i<8180;i++)
    if(c.RAM[i]===64&&c.RAM[i+1]===64&&c.RAM[i+2]===94&&c.RAM[i+3]===62&&c.RAM[i+4]===11&&c.RAM[i+5]===14)return i
  throw new Error('could not locate hoard base coordinates in RAM')
}

test('hoard: initial layout — 8-px dragon at centre, 3x3 gem block',()=>{
  const g=run(loadCartFile('hoard.dgc'),6,0)  // a few frames so startup (incl. the HUD line) completes
  assert.equal(count(g,DRAGON),8,'dragon is 8 pixels')
  assert.equal(count(g,GEM),9,'gem is a 3x3 block (9 pixels)')
  for(let y=62;y<=64;y++)for(let x=94;x<=96;x++)
    assert.equal(pixelAt(g,x,y),GEM,`gem cell ${x},${y}`)
  for(let x=64;x<=67;x++)assert.equal(pixelAt(g,x,65),DRAGON,`dragon body cell ${x},65`)
  // score-HUD separator line spans the whole width at y=7
  let line=0;for(let x=0;x<128;x++)if(pixelAt(g,x,7)===5)line++
  assert.equal(line,128,'separator line fills row y=7')
})

test('hoard: idle is rock-steady (no flicker when not moving)',()=>{
  for(const f of [1,2,3,5,8,13,21]){
    const g=run(loadCartFile('hoard.dgc'),f,0)
    assert.equal(count(g,DRAGON),8,`dragon stable at ${f} frames`)
    assert.equal(count(g,GEM),9,`gem stable at ${f} frames`)
  }
})

test('hoard: D-pad moves the dragon and leaves no trail',()=>{
  const a=loadCartFile('hoard.dgc')
  let maxGreen=0,minY=128
  for(let f=0;f<40;f++){
    a.input=UP;a.frame()
    maxGreen=Math.max(maxGreen,count(a,DRAGON))
    for(let y=0;y<minY;y++)for(let x=0;x<128;x++)if(pixelAt(a,x,y)===DRAGON){minY=y;break}
  }
  assert.ok(maxGreen<=8,`no trail: never more than 8 green (saw ${maxGreen})`)
  assert.ok(minY<60,`dragon climbed well above the start row (reached y=${minY})`)
})

test('hoard: box collision — catches anywhere in the gem cell, misses just outside',()=>{
  // Catch at the box corner (body cell 94,62): step in and let it settle.
  const hit=loadCartFile('hoard.dgc'),B=baseAddr(hit)
  hit.RAM[B]=92;hit.RAM[B+1]=61               // body will step into (94,62)
  const gx0=hit.RAM[B+2]
  for(let f=0;f<12;f++){hit.input=RIGHT;hit.frame()}
  assert.notEqual(hit.RAM[B+2],gx0,'corner of the 3x3 zone counts as a catch')

  // Just outside (body cell 93,61, y above the box): must not catch.
  const miss=loadCartFile('hoard.dgc')
  miss.RAM[B]=91;miss.RAM[B+1]=60
  const gx1=miss.RAM[B+2]
  for(let f=0;f<12;f++){miss.input=RIGHT;miss.frame()}
  assert.equal(miss.RAM[B+2],gx1,'one pixel outside the zone is not a catch')
})

test('hoard: catching cycles the gem through its four positions',()=>{
  const a=loadCartFile('hoard.dgc'),B=baseAddr(a)
  let catches=0,last=a.RAM[B+2]
  const xs=new Set([a.RAM[B+2]])
  for(let f=0;f<5000&&catches<4;f++){
    const bx=a.RAM[B]+1,by=a.RAM[B+1]+1,gx=a.RAM[B+2]+1,gy=a.RAM[B+3]+1
    let inp=0
    if(bx<gx)inp=8;else if(bx>gx)inp=4;else if(by<gy)inp=2;else if(by>gy)inp=1
    a.input=inp;a.frame()
    if(a.RAM[B+2]!==last){catches++;last=a.RAM[B+2];xs.add(last)}
  }
  assert.ok(catches>=4,`caught at least 4 gems (got ${catches})`)
  assert.equal(xs.size,4,'gem visits four distinct positions')
})

test('hoard: the dragon cannot leave the screen (edges clamp)',()=>{
  // base legal range is bx 0..124, by 0..125 (sprite spans +3 / +2)
  function hold(dir,n){
    const a=loadCartFile('hoard.dgc'),B=baseAddr(a)
    for(let f=0;f<n;f++){a.input=dir;a.frame()}
    return [a.RAM[B],a.RAM[B+1]]
  }
  assert.deepEqual(hold(4,300),[0,64],'holding Left clamps bx at 0')
  assert.deepEqual(hold(8,400),[124,64],'holding Right clamps bx at 124')
  assert.deepEqual(hold(1,300),[64,8],'holding Up clamps by at 8 (score HUD reserved)')
  assert.deepEqual(hold(2,400),[64,125],'holding Down clamps by at 125')
})

test('hoard: gems change colour as they cycle',()=>{
  const a=loadCartFile('hoard.dgc'),B=baseAddr(a),GCOL=B+5
  let last=a.RAM[B+2],catches=0
  const colours=new Set([a.RAM[GCOL]])
  for(let f=0;f<5000&&catches<4;f++){
    const bx=a.RAM[B]+1,by=a.RAM[B+1]+1,gx=a.RAM[B+2]+1,gy=a.RAM[B+3]+1
    let inp=0
    if(bx<gx)inp=8;else if(bx>gx)inp=4;else if(by<gy)inp=2;else if(by>gy)inp=1
    a.input=inp;a.frame()
    if(a.RAM[B+2]!==last){catches++;last=a.RAM[B+2];colours.add(a.RAM[GCOL])}
  }
  assert.equal(colours.size,4,'four positions show four distinct colours')
  assert.ok(!colours.has(0),'no gem is drawn in the background colour')
})

test('hoard: the gold coin scores 3 pips, gems score 1',()=>{
  const a=loadCartFile('hoard.dgc'),B=baseAddr(a)
  const pipCount=()=>{let n=0;for(let x=0;x<128;x++)if(pixelAt(a,x,4)===7)n++;return n}
  let last=a.RAM[B+2],catches=0,prev=0
  const deltas=[]
  for(let f=0;f<6000&&catches<4;f++){
    const bx=a.RAM[B]+1,by=a.RAM[B+1]+1,gx=a.RAM[B+2]+1,gy=a.RAM[B+3]+1
    let inp=0
    if(bx<gx)inp=8;else if(bx>gx)inp=4;else if(by<gy)inp=2;else if(by>gy)inp=1
    a.input=inp;a.frame()
    if(a.RAM[B+2]!==last){catches++;last=a.RAM[B+2];const p=pipCount();deltas.push(p-prev);prev=p}
  }
  // pickups are caught in order gem, gem, coin, gem
  assert.deepEqual(deltas,[1,1,3,1],'coin (3rd pickup) awards 3 pips, gems award 1')
})

test('hoard: the dragon cannot erase its own score (HUD is protected)',()=>{
  const a=loadCartFile('hoard.dgc'),B=baseAddr(a)
  const pips=()=>{let n=0;for(let x=0;x<128;x++)if(pixelAt(a,x,4)===7)n++;return n}
  // earn a few pips
  let last=a.RAM[B+2],catches=0
  for(let f=0;f<3000&&catches<3;f++){
    const bx=a.RAM[B]+1,by=a.RAM[B+1]+1,gx=a.RAM[B+2]+1,gy=a.RAM[B+3]+1
    let inp=0
    if(bx<gx)inp=8;else if(bx>gx)inp=4;else if(by<gy)inp=2;else if(by>gy)inp=1
    a.input=inp;a.frame()
    if(a.RAM[B+2]!==last){catches++;last=a.RAM[B+2]}
  }
  const score=pips()
  assert.ok(score>0,'earned some score to test with')
  // ram up into the HUD band and sweep the whole top row
  for(let f=0;f<200;f++){a.input=1;a.frame()}
  for(let f=0;f<400;f++){a.input=4;a.frame()}
  for(let f=0;f<800;f++){a.input=8;a.frame()}
  assert.equal(pips(),score,'score pips survive the dragon roaming the top')
})
