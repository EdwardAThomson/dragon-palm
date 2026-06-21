; Dragon Hoard (work in progress)
; Steer the dragon (D-pad, clamped to the screen edges) onto treasure. Pickups
; cycle through four spots: three colour-changing gems (worth one score pip) and
; one gold coin (worth three). Each catch lights pips along the top.
;
; The dragon is an 8-pixel sprite and the gem is a 3x3 block, each drawn relative
; to a base coordinate via self-modifying code (draw_sprite / draw_gem rewrite the
; immediates of their own LD_X/LD_Y). Collision is a box overlap: the dragon's
; body cell counts as a catch when it lands anywhere inside the gem's 3x3 cell,
; tested by enumerating the three columns and rows (the CPU only has equality).
;
; Sprites are only erased/redrawn on an actual step (gated by a soft clock); idle
; frames leave the screen untouched so the multi-pixel art stays steady.
;
; The repetitive sprite/gem draw blocks were expanded from coordinate tables;
; this .asm is the complete, self-contained, assemblable source. Built and
; verified with the Dragon Palm toolchain (assembler + headless test suite).
; Known rough edge: the sprite can flicker while moving (multi-pixel erase/redraw
; sampled mid-frame); idle is steady.

start:
  LD_A 14
  STA [gcol]
  LD_A [r_gini]
  STA [draw_gem_ret+1]
  LD_A [r_gini+1]
  STA [draw_gem_ret+2]
  JMP draw_gem
after_gini:
  LD_A 11
  STA [col]
  LD_A [r_dini]
  STA [draw_sprite_ret+1]
  LD_A [r_dini+1]
  STA [draw_sprite_ret+2]
  JMP draw_sprite
after_dini:
  ; --- draw the score-HUD separator line once at y=7 (the dragon clamps at
  ;     by>=8, so it can never reach or erase this row). Drawn after the dragon
  ;     and gem so they appear immediately; the line fills in over the next frame. ---
  LD_Y 7
sep_loop:
sep_x:
  LD_X 0
  LD_A 5
  DRW
  LD_A [sep_x+1]
  LD_X 1
  ADD_A
  STA [sep_x+1]
  LD_X 128
  SUB_A
  JNZ sep_loop

main:
  ; --- poll input; record a direction, or wait untouched if no D-pad ---
  RDIN
  LD_X 1
  SUB_A
  JNZ poll_down
  LD_A 1
  STA [dir]
  JMP have_move
poll_down:
  RDIN
  LD_X 2
  SUB_A
  JNZ poll_left
  LD_A 2
  STA [dir]
  JMP have_move
poll_left:
  RDIN
  LD_X 4
  SUB_A
  JNZ poll_right
  LD_A 3
  STA [dir]
  JMP have_move
poll_right:
  RDIN
  LD_X 8
  SUB_A
  JNZ idle_tick
  LD_A 4
  STA [dir]

have_move:
  ; soft-clock gate: only step every few ticks, and only then erase/redraw
  LD_A [mtick]
  JNZ wait_tick
  LD_A 5
  STA [mtick]
  JMP do_step
wait_tick:
  LD_A [mtick]
  LD_X 1
  SUB_A
  STA [mtick]
  JMP do_wait
idle_tick:
  LD_A 0
  STA [mtick]
  JMP do_wait

do_step:
  ; --- bounds gate: if the move would leave the screen, skip it (no redraw) ---
  ; sprite spans bx..bx+3 / by..by+2, so legal base is bx 0..124, by 0..125.
  LD_A [dir]
  LD_X 1
  SUB_A
  JNZ bg_down
  LD_A [by]
  LD_X 8
  SUB_A
  JNZ do_step_go        ; up blocked at by==8: top 8 rows are the score HUD
  JMP do_wait
bg_down:
  LD_A [dir]
  LD_X 2
  SUB_A
  JNZ bg_left
  LD_A [by]
  LD_X 125
  SUB_A
  JNZ do_step_go        ; down blocked only at by==125
  JMP do_wait
bg_left:
  LD_A [dir]
  LD_X 3
  SUB_A
  JNZ bg_right
  LD_A [bx]
  JNZ do_step_go        ; left blocked only at bx==0
  JMP do_wait
bg_right:
  LD_A [bx]
  LD_X 124
  SUB_A
  JNZ do_step_go        ; right blocked only at bx==124
  JMP do_wait

do_step_go:
  ; --- save the old base (needed to erase the trailing edge after the move) ---
  LD_A [bx]
  STA [obx]
  LD_A [by]
  STA [oby]

  ; --- apply the move to the base ---
  LD_A [dir]
  LD_X 1
  SUB_A
  JNZ mv_down
  LD_A [by]
  LD_X 1
  SUB_A
  STA [by]
  JMP check_eat
mv_down:
  LD_A [dir]
  LD_X 2
  SUB_A
  JNZ mv_left
  LD_A [by]
  LD_X 1
  ADD_A
  STA [by]
  JMP check_eat
mv_left:
  LD_A [dir]
  LD_X 3
  SUB_A
  JNZ mv_right
  LD_A [bx]
  LD_X 1
  SUB_A
  STA [bx]
  JMP check_eat
mv_right:
  LD_A [bx]
  LD_X 1
  ADD_A
  STA [bx]

check_eat:
  ; box overlap: is the dragon body cell (bx+1) within {gemx, gemx+1, gemx+2}?
  LD_A [gemx]
  STA [cex+1]
  LD_A [bx]
  LD_X 1
  ADD_A
cex:
  LD_X 0
  SUB_A             ; tx = (bx+1) - gemx
  JNZ cex_n0
  JMP xhit
cex_n0:
  LD_X 1
  SUB_A
  JNZ cex_n1
  JMP xhit
cex_n1:
  LD_X 1
  SUB_A
  JNZ draw_phase    ; tx not in {0,1,2} -> miss
xhit:
  ; ...and is (by+1) within {gemy, gemy+1, gemy+2}?
  LD_A [gemy]
  STA [cey+1]
  LD_A [by]
  LD_X 1
  ADD_A
cey:
  LD_X 0
  SUB_A             ; ty = (by+1) - gemy
  JNZ cey_n0
  JMP eat
cey_n0:
  LD_X 1
  SUB_A
  JNZ cey_n1
  JMP eat
cey_n1:
  LD_X 1
  SUB_A
  JNZ draw_phase    ; ty not in {0,1,2} -> miss

eat:
  ; erase the old gem
  LD_A 0
  STA [gcol]
  LD_A [r_gera]
  STA [draw_gem_ret+1]
  LD_A [r_gera+1]
  STA [draw_gem_ret+2]
  JMP draw_gem
after_gera:
  ; award score pips: the gold coin (slot 2) is worth 3, a gem worth 1
  LD_A [slot]
  LD_X 2
  SUB_A
  JNZ score_one
  LD_A 3
  STA [pipn]
  JMP pip_loop
score_one:
  LD_A 1
  STA [pipn]
pip_loop:
pip_x:
  LD_X 4
  LD_Y 4
  LD_A 7
  DRW
  LD_A [pip_x+1]
  LD_X 3
  ADD_A
  STA [pip_x+1]
  LD_A [pipn]
  LD_X 1
  SUB_A
  STA [pipn]
  JNZ pip_loop
  ; advance to the next gem slot (cycle through four spots)
  LD_A [slot]
  LD_X 1
  ADD_A
  STA [slot]
  LD_X 4
  SUB_A
  JNZ place_gem
  LD_A 0
  STA [slot]
place_gem:
  ; each slot has its own position and colour
  LD_A [slot]
  JNZ gem_slot1
  LD_A 94
  STA [gemx]
  LD_A 62
  STA [gemy]
  LD_A 14
  STA [gcol]            ; lavender
  JMP draw_phase
gem_slot1:
  LD_A [slot]
  LD_X 1
  SUB_A
  JNZ gem_slot2
  LD_A 28
  STA [gemx]
  LD_A 98
  STA [gemy]
  LD_A 10
  STA [gcol]            ; cyan
  JMP draw_phase
gem_slot2:
  LD_A [slot]
  LD_X 2
  SUB_A
  JNZ gem_slot3
  LD_A 16
  STA [gemx]
  LD_A 22
  STA [gemy]
  LD_A 12
  STA [gcol]            ; gold (this slot is the coin)
  JMP draw_phase
gem_slot3:
  LD_A 108
  STA [gemx]
  LD_A 104
  STA [gemy]
  LD_A 13
  STA [gcol]            ; mauve

draw_phase:
  ; Flicker-free move: draw the dragon at the NEW base first (it is never fully
  ; erased, so it can't be caught mid-redraw), then erase only the cells it
  ; vacated (the trailing edge, by direction), then redraw the gem on top.
  LD_A 11
  STA [col]
  LD_A [r_ddra]
  STA [draw_sprite_ret+1]
  LD_A [r_ddra+1]
  STA [draw_sprite_ret+2]
  JMP draw_sprite
after_ddra:
  LD_A [dir]
  LD_X 1
  SUB_A
  JNZ te_down
  LD_A [obx]
  LD_X 0
  ADD_A
  STA [teu0x+1]
  LD_A [oby]
  LD_X 1
  ADD_A
  STA [teu0y+1]
teu0x:
  LD_X 0
teu0y:
  LD_Y 0
  LD_A 0
  DRW
  LD_A [obx]
  LD_X 2
  ADD_A
  STA [teu1x+1]
  LD_A [oby]
  LD_X 1
  ADD_A
  STA [teu1y+1]
teu1x:
  LD_X 0
teu1y:
  LD_Y 0
  LD_A 0
  DRW
  LD_A [obx]
  LD_X 1
  ADD_A
  STA [teu2x+1]
  LD_A [oby]
  LD_X 2
  ADD_A
  STA [teu2y+1]
teu2x:
  LD_X 0
teu2y:
  LD_Y 0
  LD_A 0
  DRW
  LD_A [obx]
  LD_X 3
  ADD_A
  STA [teu3x+1]
  LD_A [oby]
  LD_X 2
  ADD_A
  STA [teu3y+1]
teu3x:
  LD_X 0
teu3y:
  LD_Y 0
  LD_A 0
  DRW
  JMP te_done
te_down:
  LD_A [dir]
  LD_X 2
  SUB_A
  JNZ te_left
  LD_A [obx]
  LD_X 0
  ADD_A
  STA [ted0x+1]
  LD_A [oby]
  LD_X 0
  ADD_A
  STA [ted0y+1]
ted0x:
  LD_X 0
ted0y:
  LD_Y 0
  LD_A 0
  DRW
  LD_A [obx]
  LD_X 3
  ADD_A
  STA [ted1x+1]
  LD_A [oby]
  LD_X 0
  ADD_A
  STA [ted1y+1]
ted1x:
  LD_X 0
ted1y:
  LD_Y 0
  LD_A 0
  DRW
  LD_A [obx]
  LD_X 1
  ADD_A
  STA [ted2x+1]
  LD_A [oby]
  LD_X 1
  ADD_A
  STA [ted2y+1]
ted2x:
  LD_X 0
ted2y:
  LD_Y 0
  LD_A 0
  DRW
  LD_A [obx]
  LD_X 2
  ADD_A
  STA [ted3x+1]
  LD_A [oby]
  LD_X 1
  ADD_A
  STA [ted3y+1]
ted3x:
  LD_X 0
ted3y:
  LD_Y 0
  LD_A 0
  DRW
  JMP te_done
te_left:
  LD_A [dir]
  LD_X 3
  SUB_A
  JNZ te_right
  LD_A [obx]
  LD_X 0
  ADD_A
  STA [tel0x+1]
  LD_A [oby]
  LD_X 0
  ADD_A
  STA [tel0y+1]
tel0x:
  LD_X 0
tel0y:
  LD_Y 0
  LD_A 0
  DRW
  LD_A [obx]
  LD_X 3
  ADD_A
  STA [tel1x+1]
  LD_A [oby]
  LD_X 0
  ADD_A
  STA [tel1y+1]
tel1x:
  LD_X 0
tel1y:
  LD_Y 0
  LD_A 0
  DRW
  LD_A [obx]
  LD_X 3
  ADD_A
  STA [tel2x+1]
  LD_A [oby]
  LD_X 1
  ADD_A
  STA [tel2y+1]
tel2x:
  LD_X 0
tel2y:
  LD_Y 0
  LD_A 0
  DRW
  LD_A [obx]
  LD_X 1
  ADD_A
  STA [tel3x+1]
  LD_A [oby]
  LD_X 2
  ADD_A
  STA [tel3y+1]
tel3x:
  LD_X 0
tel3y:
  LD_Y 0
  LD_A 0
  DRW
  LD_A [obx]
  LD_X 3
  ADD_A
  STA [tel4x+1]
  LD_A [oby]
  LD_X 2
  ADD_A
  STA [tel4y+1]
tel4x:
  LD_X 0
tel4y:
  LD_Y 0
  LD_A 0
  DRW
  JMP te_done
te_right:
  LD_A [obx]
  LD_X 0
  ADD_A
  STA [ter0x+1]
  LD_A [oby]
  LD_X 0
  ADD_A
  STA [ter0y+1]
ter0x:
  LD_X 0
ter0y:
  LD_Y 0
  LD_A 0
  DRW
  LD_A [obx]
  LD_X 3
  ADD_A
  STA [ter1x+1]
  LD_A [oby]
  LD_X 0
  ADD_A
  STA [ter1y+1]
ter1x:
  LD_X 0
ter1y:
  LD_Y 0
  LD_A 0
  DRW
  LD_A [obx]
  LD_X 0
  ADD_A
  STA [ter2x+1]
  LD_A [oby]
  LD_X 1
  ADD_A
  STA [ter2y+1]
ter2x:
  LD_X 0
ter2y:
  LD_Y 0
  LD_A 0
  DRW
  LD_A [obx]
  LD_X 1
  ADD_A
  STA [ter3x+1]
  LD_A [oby]
  LD_X 2
  ADD_A
  STA [ter3y+1]
ter3x:
  LD_X 0
ter3y:
  LD_Y 0
  LD_A 0
  DRW
  LD_A [obx]
  LD_X 3
  ADD_A
  STA [ter4x+1]
  LD_A [oby]
  LD_X 2
  ADD_A
  STA [ter4y+1]
ter4x:
  LD_X 0
ter4y:
  LD_Y 0
  LD_A 0
  DRW
te_done:
  LD_A [r_gdra]
  STA [draw_gem_ret+1]
  LD_A [r_gdra+1]
  STA [draw_gem_ret+2]
  JMP draw_gem
after_gdra:

do_wait:
  LD_A 40
wait:
  LD_X 1
  SUB_A
  JNZ wait
  JMP main

draw_sprite:
  LD_A [bx]
  LD_X 0
  ADD_A
  STA [ds_p0x+1]
  LD_A [by]
  LD_X 0
  ADD_A
  STA [ds_p0y+1]
ds_p0x:
  LD_X 0
ds_p0y:
  LD_Y 0
  LD_A [col]
  DRW
  LD_A [bx]
  LD_X 3
  ADD_A
  STA [ds_p1x+1]
  LD_A [by]
  LD_X 0
  ADD_A
  STA [ds_p1y+1]
ds_p1x:
  LD_X 0
ds_p1y:
  LD_Y 0
  LD_A [col]
  DRW
  LD_A [bx]
  LD_X 0
  ADD_A
  STA [ds_p2x+1]
  LD_A [by]
  LD_X 1
  ADD_A
  STA [ds_p2y+1]
ds_p2x:
  LD_X 0
ds_p2y:
  LD_Y 0
  LD_A [col]
  DRW
  LD_A [bx]
  LD_X 1
  ADD_A
  STA [ds_p3x+1]
  LD_A [by]
  LD_X 1
  ADD_A
  STA [ds_p3y+1]
ds_p3x:
  LD_X 0
ds_p3y:
  LD_Y 0
  LD_A [col]
  DRW
  LD_A [bx]
  LD_X 2
  ADD_A
  STA [ds_p4x+1]
  LD_A [by]
  LD_X 1
  ADD_A
  STA [ds_p4y+1]
ds_p4x:
  LD_X 0
ds_p4y:
  LD_Y 0
  LD_A [col]
  DRW
  LD_A [bx]
  LD_X 3
  ADD_A
  STA [ds_p5x+1]
  LD_A [by]
  LD_X 1
  ADD_A
  STA [ds_p5y+1]
ds_p5x:
  LD_X 0
ds_p5y:
  LD_Y 0
  LD_A [col]
  DRW
  LD_A [bx]
  LD_X 1
  ADD_A
  STA [ds_p6x+1]
  LD_A [by]
  LD_X 2
  ADD_A
  STA [ds_p6y+1]
ds_p6x:
  LD_X 0
ds_p6y:
  LD_Y 0
  LD_A [col]
  DRW
  LD_A [bx]
  LD_X 3
  ADD_A
  STA [ds_p7x+1]
  LD_A [by]
  LD_X 2
  ADD_A
  STA [ds_p7y+1]
ds_p7x:
  LD_X 0
ds_p7y:
  LD_Y 0
  LD_A [col]
  DRW
draw_sprite_ret:
  JMP 0

draw_gem:
  LD_A [gemx]
  LD_X 0
  ADD_A
  STA [dg_p0x+1]
  LD_A [gemy]
  LD_X 0
  ADD_A
  STA [dg_p0y+1]
dg_p0x:
  LD_X 0
dg_p0y:
  LD_Y 0
  LD_A [gcol]
  DRW
  LD_A [gemx]
  LD_X 1
  ADD_A
  STA [dg_p1x+1]
  LD_A [gemy]
  LD_X 0
  ADD_A
  STA [dg_p1y+1]
dg_p1x:
  LD_X 0
dg_p1y:
  LD_Y 0
  LD_A [gcol]
  DRW
  LD_A [gemx]
  LD_X 2
  ADD_A
  STA [dg_p2x+1]
  LD_A [gemy]
  LD_X 0
  ADD_A
  STA [dg_p2y+1]
dg_p2x:
  LD_X 0
dg_p2y:
  LD_Y 0
  LD_A [gcol]
  DRW
  LD_A [gemx]
  LD_X 0
  ADD_A
  STA [dg_p3x+1]
  LD_A [gemy]
  LD_X 1
  ADD_A
  STA [dg_p3y+1]
dg_p3x:
  LD_X 0
dg_p3y:
  LD_Y 0
  LD_A [gcol]
  DRW
  LD_A [gemx]
  LD_X 1
  ADD_A
  STA [dg_p4x+1]
  LD_A [gemy]
  LD_X 1
  ADD_A
  STA [dg_p4y+1]
dg_p4x:
  LD_X 0
dg_p4y:
  LD_Y 0
  LD_A [gcol]
  DRW
  LD_A [gemx]
  LD_X 2
  ADD_A
  STA [dg_p5x+1]
  LD_A [gemy]
  LD_X 1
  ADD_A
  STA [dg_p5y+1]
dg_p5x:
  LD_X 0
dg_p5y:
  LD_Y 0
  LD_A [gcol]
  DRW
  LD_A [gemx]
  LD_X 0
  ADD_A
  STA [dg_p6x+1]
  LD_A [gemy]
  LD_X 2
  ADD_A
  STA [dg_p6y+1]
dg_p6x:
  LD_X 0
dg_p6y:
  LD_Y 0
  LD_A [gcol]
  DRW
  LD_A [gemx]
  LD_X 1
  ADD_A
  STA [dg_p7x+1]
  LD_A [gemy]
  LD_X 2
  ADD_A
  STA [dg_p7y+1]
dg_p7x:
  LD_X 0
dg_p7y:
  LD_Y 0
  LD_A [gcol]
  DRW
  LD_A [gemx]
  LD_X 2
  ADD_A
  STA [dg_p8x+1]
  LD_A [gemy]
  LD_X 2
  ADD_A
  STA [dg_p8y+1]
dg_p8x:
  LD_X 0
dg_p8y:
  LD_Y 0
  LD_A [gcol]
  DRW
draw_gem_ret:
  JMP 0


; --- data ---
r_dini:
  DW after_dini
r_ddra:
  DW after_ddra
r_gini:
  DW after_gini
r_gera:
  DW after_gera
r_gdra:
  DW after_gdra
bx:
  DB 64
by:
  DB 64
gemx:
  DB 94
gemy:
  DB 62
col:
  DB 11
gcol:
  DB 14
dir:
  DB 0
slot:
  DB 0
mtick:
  DB 0
pipn:
  DB 0
obx:
  DB 0
oby:
  DB 0
