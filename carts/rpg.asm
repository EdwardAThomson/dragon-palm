; ============================================================================
; Dragon Quest for the Hoard -- Milestone 4
; M1 HUD + M2 room/player + M3 room flips + an enemy that triggers COMBAT.
; See docs/rpg.md. Respects hardware-is-gospel: only the 11 opcodes, no access
; outside the memory map, colour masked to 0-15.
;
; M4 over M3:
;   * One enemy entity (room page, col, row, alive). It is drawn as a red cell
;     and lives on the door row of room 1, guarding the way east.
;   * Stepping onto the live enemy's cell switches STATE to COMBAT instead of
;     moving onto it.
;   * COMBAT is still a placeholder: the viewport flat-fills a distinct colour so
;     the mode change is visible, and Start flees back to EXPLORE (so nothing
;     soft-locks). The real turn-based fight is M5.
;   * Room/enemy/player painting is unified into paint_scene (boot, room entry,
;     and combat-return all call it). draw_room gained a flat-colour override so
;     the combat backdrop can reuse it.
; ============================================================================

; --- Variable / scratch page ($1F00). Zero-initialised by cart padding. ---
VX0      EQU $1F00
VY       EQU $1F01
VW0      EQU $1F02
VH       EQU $1F03
VX       EQU $1F04
VW       EQU $1F05
VCOL     EQU $1F06
DPTR     EQU $1F07
STATE    EQU $1F08     ; 0 = EXPLORE, 1 = COMBAT, 2 = GAMEOVER
PCOL     EQU $1F09
PROW     EQU $1F0A
TCOL     EQU $1F0B
TROW     EQU $1F0C
DIR      EQU $1F0D
MTICK    EQU $1F0E
DC_COL   EQU $1F0F
DC_ROW   EQU $1F10
DC_COLOR EQU $1F11
DR_COL   EQU $1F12
DR_ROW   EQU $1F13
CURROOM  EQU $1F14     ; current room page high byte ($15..$18)
ENEMY_ROOM  EQU $1F15  ; enemy location + state
ENEMY_COL   EQU $1F16
ENEMY_ROW   EQU $1F17
ENEMY_ALIVE EQU $1F18
DRAW_FLAT   EQU $1F19  ; 0 = paint map colours; nonzero = paint this flat colour

; --- Table base addresses ---
mul8       EQU $1A00
room       EQU $1500   ; room map base; high byte patched to CURROOM per read
tile_col   EQU $1C00
tile_solid EQU $1D00
desc       EQU $1E00

FLOOR_COL   EQU 5
PLAYER_COL  EQU 11
ENEMY_COLOR EQU 8       ; red
COMBAT_BG   EQU 2       ; purple combat backdrop
ROOM0       EQU $15

  ORG $0000
start:
  LD_A 0
  STA [DPTR]
  LD_A $16             ; enemy guards room 1...
  STA [ENEMY_ROOM]
  LD_A 4               ; ...at cell (4,3), on the door row
  STA [ENEMY_COL]
  LD_A 3
  STA [ENEMY_ROW]
  LD_A 1
  STA [ENEMY_ALIVE]

; ---------------------------------------------------------------------------
; HUD paint (descriptor walker).
; ---------------------------------------------------------------------------
next_rect:
  LD_A [DPTR]
  STA [rd0+1]
rd0:
  LD_A [desc]
  STA [VX0]
  LD_A [DPTR]
  LD_X 1
  ADD_A
  STA [rd1+1]
rd1:
  LD_A [desc]
  STA [VY]
  LD_A [DPTR]
  LD_X 2
  ADD_A
  STA [rd2+1]
rd2:
  LD_A [desc]
  STA [VW0]
  LD_A [DPTR]
  LD_X 3
  ADD_A
  STA [rd3+1]
rd3:
  LD_A [desc]
  STA [VH]
  LD_A [DPTR]
  LD_X 4
  ADD_A
  STA [rd4+1]
rd4:
  LD_A [desc]
  STA [VCOL]
  LD_A [VW0]
  JNZ hud_fill
  JMP boot_world

hud_fill:
hf_row:
  LD_A [VY]
  STA [hfy+1]
  LD_A [VX0]
  STA [VX]
  LD_A [VW0]
  STA [VW]
hf_col:
  LD_A [VX]
  STA [hfx+1]
hfx:
  LD_X 0
hfy:
  LD_Y 0
  LD_A [VCOL]
  DRW
  LD_A [VX]
  LD_X 1
  ADD_A
  STA [VX]
  LD_A [VW]
  LD_X 1
  SUB_A
  STA [VW]
  JNZ hf_col
  LD_A [VY]
  LD_X 1
  ADD_A
  STA [VY]
  LD_A [VH]
  LD_X 1
  SUB_A
  STA [VH]
  JNZ hf_row
  LD_A [DPTR]
  LD_X 5
  ADD_A
  STA [DPTR]
  JMP next_rect

; ---------------------------------------------------------------------------
; Boot the world: room 0, player at (1,1), paint the scene, run the loop.
; ---------------------------------------------------------------------------
boot_world:
  LD_A ROOM0
  STA [CURROOM]
  LD_A 1
  STA [PCOL]
  LD_A 1
  STA [PROW]
  LD_A [r_bw_scene]
  STA [paint_scene_ret+1]
  LD_A [r_bw_scene+1]
  STA [paint_scene_ret+2]
  JMP paint_scene
after_bw_scene:
  JMP main

; ---------------------------------------------------------------------------
; State machine.
; ---------------------------------------------------------------------------
main:
  LD_A [STATE]
  JNZ not_explore
  JMP explore
not_explore:
  LD_X 1
  SUB_A
  JNZ not_combat
  JMP combat
not_combat:
  JMP gameover

gameover:
  JMP gameover          ; TODO

; --- COMBAT placeholder: wait for Start, then flee back to EXPLORE (M5: real fight) ---
combat:
  RDIN
  LD_X 64
  SUB_A
  JNZ combat            ; spin until Start alone is pressed
  LD_A 0
  STA [STATE]
  LD_A [r_cb_scene]
  STA [paint_scene_ret+1]
  LD_A [r_cb_scene+1]
  STA [paint_scene_ret+2]
  JMP paint_scene
after_cb_scene:
  JMP main

; --- EXPLORE: poll input -> gate -> attempt a grid step ---
explore:
  RDIN
  LD_X 1
  SUB_A
  JNZ ex_pd
  LD_A 1
  STA [DIR]
  JMP ex_gate
ex_pd:
  RDIN
  LD_X 2
  SUB_A
  JNZ ex_pl
  LD_A 2
  STA [DIR]
  JMP ex_gate
ex_pl:
  RDIN
  LD_X 4
  SUB_A
  JNZ ex_pr
  LD_A 3
  STA [DIR]
  JMP ex_gate
ex_pr:
  RDIN
  LD_X 8
  SUB_A
  JNZ ex_none
  LD_A 4
  STA [DIR]
ex_gate:
  LD_A [MTICK]
  JNZ ex_dec
  LD_A 3
  STA [MTICK]
  JMP do_move
ex_dec:
  LD_A [MTICK]
  LD_X 1
  SUB_A
  STA [MTICK]
  JMP main
ex_none:
  LD_A 0
  STA [MTICK]
  JMP main

do_move:
  LD_A [PCOL]
  STA [TCOL]
  LD_A [PROW]
  STA [TROW]
  LD_A [DIR]
  LD_X 1
  SUB_A
  JNZ dm_down
  LD_A [TROW]
  LD_X 1
  SUB_A
  STA [TROW]
  JMP dm_check
dm_down:
  LD_A [DIR]
  LD_X 2
  SUB_A
  JNZ dm_left
  LD_A [TROW]
  LD_X 1
  ADD_A
  STA [TROW]
  JMP dm_check
dm_left:
  LD_A [DIR]
  LD_X 3
  SUB_A
  JNZ dm_right
  LD_A [TCOL]
  LD_X 1
  SUB_A
  STA [TCOL]
  JMP dm_check
dm_right:
  LD_A [TCOL]
  LD_X 1
  ADD_A
  STA [TCOL]
dm_check:
  ; solid = tile_solid[ room[ MUL8[TROW] + TCOL ] ]
  LD_A [TCOL]
  STA [dm_setx+1]
dm_setx:
  LD_X 0
  LD_A [TROW]
  STA [dm_mul+1]
dm_mul:
  LD_A [mul8]
  ADD_A
  STA [dm_map+1]
  LD_A [CURROOM]
  STA [dm_map+2]
dm_map:
  LD_A [room]
  STA [dm_sol+1]
dm_sol:
  LD_A [tile_solid]
  JNZ main              ; wall -> blocked
  ; --- enemy check: is the target the live enemy's cell? ---
  LD_A [ENEMY_ALIVE]
  JNZ dm_en_room
  JMP dm_do_move
dm_en_room:
  LD_A [ENEMY_ROOM]
  STA [dm_enr+1]
dm_enr:
  LD_X 0
  LD_A [CURROOM]
  SUB_A
  JNZ dm_do_move        ; enemy not in this room
  LD_A [ENEMY_COL]
  STA [dm_enc+1]
dm_enc:
  LD_X 0
  LD_A [TCOL]
  SUB_A
  JNZ dm_do_move
  LD_A [ENEMY_ROW]
  STA [dm_enrow+1]
dm_enrow:
  LD_X 0
  LD_A [TROW]
  SUB_A
  JNZ dm_do_move
  JMP combat_enter      ; target is the enemy -> fight

dm_do_move:
  ; --- draw player at the new cell first (flicker-free) ---
  LD_A [TCOL]
  STA [DC_COL]
  LD_A [TROW]
  STA [DC_ROW]
  LD_A PLAYER_COL
  STA [DC_COLOR]
  LD_A [r_pdraw]
  STA [fill_cell_ret+1]
  LD_A [r_pdraw+1]
  STA [fill_cell_ret+2]
  JMP fill_cell
after_pdraw:
  ; --- erase the old cell back to floor ---
  LD_A [PCOL]
  STA [DC_COL]
  LD_A [PROW]
  STA [DC_ROW]
  LD_A FLOOR_COL
  STA [DC_COLOR]
  LD_A [r_erase]
  STA [fill_cell_ret+1]
  LD_A [r_erase+1]
  STA [fill_cell_ret+2]
  JMP fill_cell
after_erase:
  ; --- commit position ---
  LD_A [TCOL]
  STA [PCOL]
  LD_A [TROW]
  STA [PROW]
  ; --- doorway check: col 7 -> east, col 0 -> west ---
  LD_A [PCOL]
  LD_X 7
  SUB_A
  JNZ mv_chk_west
  JMP go_east
mv_chk_west:
  LD_A [PCOL]
  JNZ main
  JMP go_west

go_east:
  LD_A [CURROOM]
  LD_X 1
  ADD_A
  STA [CURROOM]
  LD_A 1
  STA [PCOL]
  LD_A 3
  STA [PROW]
  JMP enter_room
go_west:
  LD_A [CURROOM]
  LD_X 1
  SUB_A
  STA [CURROOM]
  LD_A 6
  STA [PCOL]
  LD_A 3
  STA [PROW]
enter_room:
  LD_A [r_er_scene]
  STA [paint_scene_ret+1]
  LD_A [r_er_scene+1]
  STA [paint_scene_ret+2]
  JMP paint_scene
after_er_scene:
  JMP main

; ---------------------------------------------------------------------------
; combat_enter: switch to COMBAT and paint a flat backdrop over the viewport.
; ---------------------------------------------------------------------------
combat_enter:
  LD_A 1
  STA [STATE]
  LD_A COMBAT_BG
  STA [DRAW_FLAT]
  LD_A [r_ce_room]
  STA [draw_room_ret+1]
  LD_A [r_ce_room+1]
  STA [draw_room_ret+2]
  JMP draw_room
after_ce_room:
  LD_A 0
  STA [DRAW_FLAT]
  JMP main

; ---------------------------------------------------------------------------
; paint_scene: draw current room + enemy (if here & alive) + player.
; Returns via paint_scene_ret.
; ---------------------------------------------------------------------------
paint_scene:
  LD_A 0
  STA [DRAW_FLAT]       ; map-colour mode
  LD_A [r_ps_room]
  STA [draw_room_ret+1]
  LD_A [r_ps_room+1]
  STA [draw_room_ret+2]
  JMP draw_room
after_ps_room:
  LD_A [ENEMY_ALIVE]
  JNZ ps_en_room
  JMP ps_player
ps_en_room:
  LD_A [ENEMY_ROOM]
  STA [ps_cmp+1]
ps_cmp:
  LD_X 0
  LD_A [CURROOM]
  SUB_A
  JNZ ps_player         ; enemy not in this room
  LD_A [ENEMY_COL]
  STA [DC_COL]
  LD_A [ENEMY_ROW]
  STA [DC_ROW]
  LD_A ENEMY_COLOR
  STA [DC_COLOR]
  LD_A [r_ps_en]
  STA [fill_cell_ret+1]
  LD_A [r_ps_en+1]
  STA [fill_cell_ret+2]
  JMP fill_cell
after_ps_en:
ps_player:
  LD_A [r_ps_pl]
  STA [draw_player_ret+1]
  LD_A [r_ps_pl+1]
  STA [draw_player_ret+2]
  JMP draw_player
after_ps_pl:
paint_scene_ret:
  JMP 0

; ---------------------------------------------------------------------------
; draw_room: paint the CURROOM map (or a flat colour if DRAW_FLAT != 0).
; Returns via draw_room_ret.
; ---------------------------------------------------------------------------
draw_room:
  LD_A 0
  STA [DR_ROW]
dr_row_loop:
  LD_A 0
  STA [DR_COL]
dr_col_loop:
  LD_A [DR_COL]
  STA [dr_setx+1]
dr_setx:
  LD_X 0
  LD_A [DR_ROW]
  STA [dr_mul+1]
dr_mul:
  LD_A [mul8]
  ADD_A
  STA [dr_map+1]
  LD_A [CURROOM]
  STA [dr_map+2]
dr_map:
  LD_A [room]
  STA [dr_col2+1]
dr_col2:
  LD_A [tile_col]
  STA [DC_COLOR]        ; default: map colour
  LD_A [DRAW_FLAT]
  JNZ dr_use_flat
  JMP dr_have_col
dr_use_flat:
  STA [DC_COLOR]        ; override with the flat colour
dr_have_col:
  LD_A [DR_COL]
  STA [DC_COL]
  LD_A [DR_ROW]
  STA [DC_ROW]
  LD_A [r_drcell]
  STA [fill_cell_ret+1]
  LD_A [r_drcell+1]
  STA [fill_cell_ret+2]
  JMP fill_cell
after_drcell:
  LD_A [DR_COL]
  LD_X 1
  ADD_A
  STA [DR_COL]
  LD_X 8
  SUB_A
  JNZ dr_col_loop
  LD_A [DR_ROW]
  LD_X 1
  ADD_A
  STA [DR_ROW]
  LD_X 8
  SUB_A
  JNZ dr_row_loop
draw_room_ret:
  JMP 0

; ---------------------------------------------------------------------------
; draw_player: fill the player's (PCOL,PROW) cell green. Returns via
; draw_player_ret (calls fill_cell internally).
; ---------------------------------------------------------------------------
draw_player:
  LD_A [PCOL]
  STA [DC_COL]
  LD_A [PROW]
  STA [DC_ROW]
  LD_A PLAYER_COL
  STA [DC_COLOR]
  LD_A [r_dp_fill]
  STA [fill_cell_ret+1]
  LD_A [r_dp_fill+1]
  STA [fill_cell_ret+2]
  JMP fill_cell
after_dp_fill:
draw_player_ret:
  JMP 0

; ---------------------------------------------------------------------------
; fill_cell(DC_COL, DC_ROW, DC_COLOR): fill the 8x8 viewport cell.
; ---------------------------------------------------------------------------
fill_cell:
  LD_A [DC_COL]
  STA [fc_mulx+1]
fc_mulx:
  LD_A [mul8]
  LD_X 32
  ADD_A
  STA [VX0]
  LD_A [DC_ROW]
  STA [fc_muly+1]
fc_muly:
  LD_A [mul8]
  LD_X 8
  ADD_A
  STA [VY]
  LD_A 8
  STA [VW0]
  LD_A 8
  STA [VH]
  LD_A [DC_COLOR]
  STA [VCOL]
fc_row:
  LD_A [VY]
  STA [fcy+1]
  LD_A [VX0]
  STA [VX]
  LD_A [VW0]
  STA [VW]
fc_col:
  LD_A [VX]
  STA [fcx+1]
fcx:
  LD_X 0
fcy:
  LD_Y 0
  LD_A [VCOL]
  DRW
  LD_A [VX]
  LD_X 1
  ADD_A
  STA [VX]
  LD_A [VW]
  LD_X 1
  SUB_A
  STA [VW]
  JNZ fc_col
  LD_A [VY]
  LD_X 1
  ADD_A
  STA [VY]
  LD_A [VH]
  LD_X 1
  SUB_A
  STA [VH]
  JNZ fc_row
fill_cell_ret:
  JMP 0

; --- subroutine return addresses (little-endian via DW) ---
r_bw_scene: DW after_bw_scene
r_er_scene: DW after_er_scene
r_cb_scene: DW after_cb_scene
r_ce_room:  DW after_ce_room
r_ps_room:  DW after_ps_room
r_ps_en:    DW after_ps_en
r_ps_pl:    DW after_ps_pl
r_pdraw:    DW after_pdraw
r_erase:    DW after_erase
r_drcell:   DW after_drcell
r_dp_fill:  DW after_dp_fill

; ---------------------------------------------------------------------------
; Page-aligned data tables.
; ---------------------------------------------------------------------------
  ORG $1500
room0:
  DB 1, 1, 1, 1, 1, 1, 1, 1
  DB 1, 0, 0, 0, 0, 0, 0, 1
  DB 1, 0, 1, 1, 0, 0, 0, 1
  DB 1, 0, 0, 0, 0, 0, 0, 0
  DB 1, 0, 0, 1, 1, 0, 0, 1
  DB 1, 0, 0, 0, 0, 0, 0, 1
  DB 1, 0, 0, 0, 0, 0, 0, 1
  DB 1, 1, 1, 1, 1, 1, 1, 1

  ORG $1600
room1:
  DB 1, 1, 1, 1, 1, 1, 1, 1
  DB 1, 0, 0, 0, 0, 0, 0, 1
  DB 1, 0, 0, 0, 1, 1, 0, 1
  DB 0, 0, 0, 0, 0, 0, 0, 0
  DB 1, 0, 1, 1, 0, 0, 0, 1
  DB 1, 0, 0, 0, 0, 1, 0, 1
  DB 1, 0, 0, 0, 0, 0, 0, 1
  DB 1, 1, 1, 1, 1, 1, 1, 1

  ORG $1700
room2:
  DB 1, 1, 1, 1, 1, 1, 1, 1
  DB 1, 0, 0, 1, 0, 0, 0, 1
  DB 1, 0, 0, 1, 0, 1, 0, 1
  DB 0, 0, 0, 0, 0, 0, 0, 0
  DB 1, 0, 1, 0, 0, 1, 0, 1
  DB 1, 0, 1, 0, 0, 0, 0, 1
  DB 1, 0, 0, 0, 0, 0, 0, 1
  DB 1, 1, 1, 1, 1, 1, 1, 1

  ORG $1800
room3:
  DB 1, 1, 1, 1, 1, 1, 1, 1
  DB 1, 0, 0, 0, 0, 0, 0, 1
  DB 1, 0, 1, 1, 1, 1, 0, 1
  DB 0, 0, 0, 0, 0, 0, 0, 1
  DB 1, 0, 1, 1, 1, 1, 0, 1
  DB 1, 0, 0, 0, 0, 0, 0, 1
  DB 1, 0, 0, 0, 0, 0, 0, 1
  DB 1, 1, 1, 1, 1, 1, 1, 1

  ORG $1A00
mul8_data:
  DB 0, 8, 16, 24, 32, 40, 48, 56

  ORG $1C00
tile_col_data:
  DB 5, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

  ORG $1D00
tile_solid_data:
  DB 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

  ORG $1E00
desc_data:
  DB 30,  6, 68,  2, 6
  DB 30, 72, 68,  2, 6
  DB 30,  6,  2, 68, 6
  DB 96,  6,  2, 68, 6
  DB  8, 80,112,  2, 6
  DB  8,118,112,  2, 6
  DB  8, 80,  2, 40, 6
  DB 118, 80,  2, 40, 6
  DB 16, 90, 96,  6,11
  DB 16,100, 96,  6, 8
  DB  0,  0,  0,  0, 0
