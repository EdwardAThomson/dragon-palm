// Dragon Quest for the Hoard — Milestone 1 + 2 tests.
//
// M1 paints a static HUD: a 2px frame (colour 6) around a 64x64 viewport, a HUD
// box below it, and two HP bars (player green 11, enemy red 8).
// M2 fills the viewport with an 8x8 tile room (brick walls 4, grey floor 5) and
// a green (11) player that walks the grid with wall collision. See docs/rpg.md.
const {test}=require('node:test')
const assert=require('node:assert/strict')
const {loadCartFile,run,pixelAt}=require('./harness.js')

const FRAME=6,PLAYER=11,ENEMY=8,WALL=4,FLOOR=5
const UP=1,DOWN=2,LEFT=4,RIGHT=8
const PCOL=0x1F09,PROW=0x1F0A,STATE=0x1F08,CURROOM=0x1F14,ENEMY_ALIVE=0x1F18
const ROOM0=0x15,ROOM3=0x18
const COMBAT_BG=2,START=64
// note: ENEMY (red 8) is defined above with the other colours
// Boot now paints the HUD AND a 64-cell room AND the player: ~200 frames of
// drawing. 400 settles it with comfortable headroom.
const BOOTED=400

const count=(c,col)=>{let n=0;for(let i=8192;i<16384;i++){if((c.RAM[i]>>4)===col)n++;if((c.RAM[i]&15)===col)n++}return n}

test('rpg M1: HUD frame, box, and both HP bars are present',()=>{
  const g=run(loadCartFile('rpg.dgc'),BOOTED,0)
  assert.equal(pixelAt(g,50,6),FRAME,'viewport top edge')
  assert.equal(pixelAt(g,30,40),FRAME,'viewport left edge')
  assert.equal(pixelAt(g,50,80),FRAME,'HUD box top edge')
  assert.equal(pixelAt(g,50,119),FRAME,'HUD box bottom edge')
  for(let x=16;x<=111;x++)assert.equal(pixelAt(g,x,92),PLAYER,`player bar at x=${x}`)
  for(let x=16;x<=111;x++)assert.equal(pixelAt(g,x,102),ENEMY,`enemy bar at x=${x}`)
})

test('rpg M2: the room renders — walls, floor, and the player on a floor cell',()=>{
  const g=run(loadCartFile('rpg.dgc'),BOOTED,0)
  assert.equal(pixelAt(g,34,10),WALL,'outer wall ring, cell (0,0)')
  assert.equal(pixelAt(g,90,10),WALL,'outer wall ring, cell (7,0)')
  assert.equal(pixelAt(g,50,26),WALL,'interior wall, cell (2,2)')
  assert.equal(pixelAt(g,58,18),FLOOR,'floor, cell (3,1)')
  assert.equal(pixelAt(g,43,19),PLAYER,'player starts on cell (1,1)')
  assert.equal(g.RAM[PCOL],1,'PCOL starts at 1')
  assert.equal(g.RAM[PROW],1,'PROW starts at 1')
})

test('rpg M2: with no input the room is rock-steady',()=>{
  const a=loadCartFile('rpg.dgc')
  run(a,BOOTED,0)
  const snap=a.RAM.slice(8192).join(',')
  for(const more of [1,5,20,100]){
    run(a,more,0)
    assert.equal(a.RAM.slice(8192).join(','),snap,`VRAM unchanged after ${more} idle frames`)
  }
})

test('rpg M2: the player walks and stops at the walls (both axes)',()=>{
  const a=loadCartFile('rpg.dgc'); run(a,BOOTED,0)
  run(a,120,RIGHT)
  assert.equal(a.RAM[PCOL],6,'RIGHT walks to col 6 and jams against the col-7 wall')
  assert.equal(a.RAM[PROW],1,'row unchanged on a horizontal walk')
  assert.equal(pixelAt(a,83,19),PLAYER,'player drawn at the new cell (6,1)')
  assert.equal(pixelAt(a,43,19),FLOOR,'vacated start cell repainted to floor (no trail)')

  const d=loadCartFile('rpg.dgc'); run(d,BOOTED,0)
  run(d,120,DOWN)
  assert.equal(d.RAM[PROW],6,'DOWN walks to row 6 and jams against the row-7 wall')
  assert.equal(d.RAM[PCOL],1,'col unchanged on a vertical walk')
})

test('rpg M2: an interior wall blocks the step',()=>{
  // Stand at (1,2); pushing RIGHT targets (2,2), which is an interior wall.
  const b=loadCartFile('rpg.dgc'); run(b,BOOTED,0)
  b.RAM[PCOL]=1; b.RAM[PROW]=2
  run(b,60,RIGHT)
  assert.equal(b.RAM[PCOL],1,'blocked: stays in column 1')
  assert.equal(b.RAM[PROW],2,'blocked: stays in row 2')
})

test('rpg M2: motion is flicker-free — the player is never fully erased',()=>{
  // draw-new-then-erase keeps a complete 8x8 (64 px) green cell on screen at all
  // times, so green never drops below one cell while moving.
  const a=loadCartFile('rpg.dgc'); run(a,BOOTED,0)
  let minGreen=999
  for(let f=0;f<120;f++){a.input=RIGHT;a.frame();minGreen=Math.min(minGreen,count(a,PLAYER))}
  assert.ok(minGreen>=64,`a full player cell is always present (min green was ${minGreen})`)
})

test('rpg M3: stepping through the east doorway flips to the next room',()=>{
  // The door is the wall gap at (7,3). Stand next to it and step RIGHT.
  const a=loadCartFile('rpg.dgc'); run(a,BOOTED,0)
  a.RAM[PCOL]=6; a.RAM[PROW]=3
  run(a,300,f=>f<15?RIGHT:0)              // step through, then let the repaint settle
  assert.equal(a.RAM[CURROOM],ROOM0+1,'CURROOM advanced one page east')
  assert.equal(a.RAM[PCOL],1,'re-entered at the west side, column 1')
  assert.equal(a.RAM[PROW],3,'re-entered on the door row')
  // room1 differs from room0 at cell (4,2): wall here, floor in room0.
  assert.equal(pixelAt(a,66,26),WALL,'the new room is painted (room1 layout)')
  assert.equal(pixelAt(a,43,35),PLAYER,'player redrawn at the entrance (1,3)')
})

test('rpg M3: the four-room chain clamps at both ends',()=>{
  // On the door row, holding a direction walks through every connected room.
  // Disable the room-1 guard so this exercises pure traversal (its blocking is
  // covered by the M4 combat tests).
  const e=loadCartFile('rpg.dgc'); run(e,BOOTED,0)
  e.RAM[ENEMY_ALIVE]=0
  e.RAM[PCOL]=1; e.RAM[PROW]=3
  run(e,1400,RIGHT)
  assert.equal(e.RAM[CURROOM],ROOM3,'east chain stops at room 3 (no further door)')
  assert.equal(e.RAM[PCOL],6,'jammed against room 3 east wall')
  run(e,1400,LEFT)
  assert.equal(e.RAM[CURROOM],ROOM0,'west chain returns to room 0 and stops')
  assert.equal(e.RAM[PCOL],1,'jammed against room 0 west wall')
})

// Flip east into room 1 (where the enemy guards cell (4,3)) and settle the repaint.
function inRoom1(){
  const a=loadCartFile('rpg.dgc'); run(a,BOOTED,0)
  a.RAM[PCOL]=6; a.RAM[PROW]=3
  run(a,320,f=>f<15?RIGHT:0)
  return a
}

test('rpg M4: the enemy is drawn in its room',()=>{
  const a=inRoom1()
  assert.equal(a.RAM[CURROOM],ROOM0+1,'reached room 1')
  assert.equal(pixelAt(a,66,34),ENEMY,'enemy painted red at cell (4,3)')
})

test('rpg M4: stepping into the enemy triggers COMBAT and blocks the move',()=>{
  const a=inRoom1()
  run(a,240,RIGHT)                          // walk (1,3)->(3,3), then into the enemy at (4,3)
  assert.equal(a.RAM[STATE],1,'STATE switched to COMBAT')
  assert.equal(a.RAM[PCOL],3,'player did not move onto the enemy cell')
  assert.equal(pixelAt(a,58,34),COMBAT_BG,'viewport shows the combat backdrop')
})

test('rpg M4: Start flees combat back to EXPLORE and repaints the room',()=>{
  const a=inRoom1()
  run(a,240,RIGHT)                          // into combat
  assert.equal(a.RAM[STATE],1,'in combat')
  run(a,300,START)                          // flee
  assert.equal(a.RAM[STATE],0,'back in EXPLORE')
  assert.equal(pixelAt(a,66,42),FLOOR,'room repainted (floor at (4,4))')
  assert.equal(pixelAt(a,66,34),ENEMY,'enemy is still there after fleeing')
})
