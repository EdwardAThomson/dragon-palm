; ============================================================================
; Dragon Quest for the Hoard -- Milestone 5 + combat-readability pass
; M1-M4 (HUD, tiled rooms, flips, enemy trigger) + real turn-based combat,
; with a legible combat screen. See docs/rpg.md. Respects hardware-is-gospel:
; only the 11 opcodes, no access outside the memory map, colour masked to 0-15.
;
; Combat:
;   * HP is stored directly as BAR-PIXEL WIDTH (0..96). The value IS the bar
;     length, so there is no scaling (no multiply needed) and the green/red HUD
;     bars drain to show live HP.
;   * The combat screen shows a FACE-OFF: the green player avatar (left) vs the
;     red enemy avatar (right) on a purple field, so the green/red HP bars below
;     read as "you" vs "them". Attacking FLASHES the enemy white, so the hit and
;     the bar drop are legible cause-and-effect (no text needed).
;   * Turn-based: press U to attack. Player hits the enemy; if it dies you WIN
;     (enemy cleared, return to EXPLORE, the guarded path opens). Otherwise the
;     enemy counterattacks; if the player dies it is GAMEOVER. Start still flees.
;     Damage divides HP evenly so it lands exactly on 0 (no borrow needed).
;   * GAMEOVER paints red and waits for Start to reset (JMP start re-inits all).
;   * fill_cell calls a general fill_rect; the HP bars and avatars reuse it.
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
CURROOM  EQU $1F14
ENEMY_ROOM  EQU $1F15
ENEMY_COL   EQU $1F16
ENEMY_ROW   EQU $1F17
ENEMY_ALIVE EQU $1F18
DRAW_FLAT   EQU $1F19
PLAYER_HP   EQU $1F1A  ; 0..96 (also the player bar width)
ENEMY_HP    EQU $1F1B  ; 0..96 (also the enemy bar width)
ATK_READY   EQU $1F1C  ; attack-button edge debounce
BAR_Y       EQU $1F1D  ; draw_bar args
BAR_COL     EQU $1F1E
BAR_HP      EQU $1F1F
BAR_EW      EQU $1F20  ; draw_bar: empty-portion width (temp)
CB_IN       EQU $1F21  ; combat: saved input byte
AV_COL      EQU $1F22  ; draw_avatar args (2x2 cell block)
AV_ROW      EQU $1F23
AV_COLOR    EQU $1F24
TILE_ID     EQU $1F25  ; tile id under the move target (for the hoard check)

; --- Table base addresses ---
mul8       EQU $1A00
room       EQU $1500
tile_col   EQU $1C00
tile_solid EQU $1D00
desc       EQU $1E00

FLOOR_COL   EQU 5
PLAYER_COL  EQU 11
ENEMY_COLOR EQU 8
COMBAT_BG   EQU 2
GAMEOVER_BG EQU 8
WIN_BG      EQU 10     ; gold victory screen
HOARD_TILE  EQU 2      ; tile id of the dragon's hoard
ROOM0       EQU $15
FULL_HP     EQU 96
PLAYER_ATK  EQU 24     ; damage the player deals (enemy dies in 4 hits)
ENEMY_ATK   EQU 12     ; damage the enemy deals (player survives 8 hits)
BAR_X       EQU 16     ; HP bar left edge
FLASH_COL   EQU 7      ; white hit-flash
PAV_COL     EQU 1      ; player avatar: 2x2 block at grid (1,3)
PAV_ROW     EQU 3
EAV_COL     EQU 5      ; enemy avatar: 2x2 block at grid (5,3)
EAV_ROW     EQU 3

  ORG $0000
start:
  LD_A 0
  STA [DPTR]
  STA [STATE]          ; A=0: EXPLORE
  LD_A FULL_HP
  STA [PLAYER_HP]
  STA [ENEMY_HP]
  LD_A $16
  STA [ENEMY_ROOM]
  LD_A 4
  STA [ENEMY_COL]
  LD_A 3
  STA [ENEMY_ROW]
  LD_A 1
  STA [ENEMY_ALIVE]
  STA [ATK_READY]      ; A=1

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
; Boot the world.
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
  JNZ not_combat       ; STATE != 1
  JMP combat
not_combat:
  LD_A [STATE]
  LD_X 2
  SUB_A
  JNZ win              ; STATE != 2 -> 3 = WIN
  JMP gameover

; --- GAMEOVER / WIN: wait for Start, then reset the whole game ---
gameover:
  RDIN
  LD_X 64
  SUB_A
  JNZ gameover
  JMP start
win:
  RDIN
  LD_X 64
  SUB_A
  JNZ win
  JMP start

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
  STA [TILE_ID]
  STA [dm_sol+1]
dm_sol:
  LD_A [tile_solid]
  JNZ main              ; wall -> blocked
  ; --- hoard tile? -> WIN ---
  LD_A [TILE_ID]
  LD_X HOARD_TILE
  SUB_A
  JNZ dm_check_enemy
  JMP win_enter
dm_check_enemy:
  ; --- enemy check ---
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
  JNZ dm_do_move
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
  JMP combat_enter

dm_do_move:
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
  LD_A [TCOL]
  STA [PCOL]
  LD_A [TROW]
  STA [PROW]
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
; COMBAT
; ---------------------------------------------------------------------------
combat_enter:
  LD_A 1
  STA [STATE]
  STA [ATK_READY]
  LD_A FULL_HP
  STA [ENEMY_HP]        ; fresh enemy each encounter
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
  ; draw the face-off avatars (green you, red enemy)
  LD_A [r_ce_bat]
  STA [draw_battlers_ret+1]
  LD_A [r_ce_bat+1]
  STA [draw_battlers_ret+2]
  JMP draw_battlers
after_ce_bat:
  LD_A [r_ce_bars]
  STA [draw_hp_bars_ret+1]
  LD_A [r_ce_bars+1]
  STA [draw_hp_bars_ret+2]
  JMP draw_hp_bars
after_ce_bars:
  JMP main

; turn handler: Start = flee, U = attack (edge-debounced)
combat:
  RDIN
  STA [CB_IN]
  LD_X 64
  SUB_A
  JNZ cb_chk_u
  JMP combat_flee
cb_chk_u:
  LD_A [CB_IN]
  LD_X 16
  SUB_A
  JNZ cb_rearm
  LD_A [ATK_READY]
  JNZ cb_go
  JMP main               ; U held, already fired
cb_go:
  LD_A 0
  STA [ATK_READY]
  JMP combat_round
cb_rearm:
  LD_A 1
  STA [ATK_READY]
  JMP main

combat_round:
  ; player attacks the enemy
  LD_A [ENEMY_HP]
  LD_X PLAYER_ATK
  SUB_A
  STA [ENEMY_HP]
  ; flash the enemy avatar white (stays lit while the bars redraw below)
  LD_A EAV_COL
  STA [AV_COL]
  LD_A EAV_ROW
  STA [AV_ROW]
  LD_A FLASH_COL
  STA [AV_COLOR]
  LD_A [r_cr_flash]
  STA [draw_avatar_ret+1]
  LD_A [r_cr_flash+1]
  STA [draw_avatar_ret+2]
  JMP draw_avatar
after_cr_flash:
  LD_A [r_cr_bars1]
  STA [draw_hp_bars_ret+1]
  LD_A [r_cr_bars1+1]
  STA [draw_hp_bars_ret+2]
  JMP draw_hp_bars
after_cr_bars1:
  LD_A [ENEMY_HP]
  JNZ cr_counter         ; enemy survived
  JMP combat_win         ; enemy dead -> win (paint_scene wipes the flash)
cr_counter:
  ; restore the enemy avatar to red
  LD_A EAV_COL
  STA [AV_COL]
  LD_A EAV_ROW
  STA [AV_ROW]
  LD_A ENEMY_COLOR
  STA [AV_COLOR]
  LD_A [r_cr_restore]
  STA [draw_avatar_ret+1]
  LD_A [r_cr_restore+1]
  STA [draw_avatar_ret+2]
  JMP draw_avatar
after_cr_restore:
  ; enemy counterattacks the player
  LD_A [PLAYER_HP]
  LD_X ENEMY_ATK
  SUB_A
  STA [PLAYER_HP]
  LD_A [r_cr_bars2]
  STA [draw_hp_bars_ret+1]
  LD_A [r_cr_bars2+1]
  STA [draw_hp_bars_ret+2]
  JMP draw_hp_bars
after_cr_bars2:
  LD_A [PLAYER_HP]
  JNZ cr_continue
  JMP combat_lose
cr_continue:
  JMP main

combat_win:
  LD_A 0
  STA [ENEMY_ALIVE]
  LD_A 0
  STA [STATE]
  LD_A [r_cw_scene]
  STA [paint_scene_ret+1]
  LD_A [r_cw_scene+1]
  STA [paint_scene_ret+2]
  JMP paint_scene
after_cw_scene:
  JMP main

combat_flee:
  LD_A 0
  STA [STATE]
  LD_A [r_cf_scene]
  STA [paint_scene_ret+1]
  LD_A [r_cf_scene+1]
  STA [paint_scene_ret+2]
  JMP paint_scene
after_cf_scene:
  JMP main

combat_lose:
  LD_A 2
  STA [STATE]
  LD_A GAMEOVER_BG
  STA [DRAW_FLAT]
  LD_A [r_cl_room]
  STA [draw_room_ret+1]
  LD_A [r_cl_room+1]
  STA [draw_room_ret+2]
  JMP draw_room
after_cl_room:
  LD_A 0
  STA [DRAW_FLAT]
  JMP main

; --- WIN: reached the hoard. Paint a gold field; Start resets. ---
win_enter:
  LD_A 3
  STA [STATE]
  LD_A WIN_BG
  STA [DRAW_FLAT]
  LD_A [r_win_room]
  STA [draw_room_ret+1]
  LD_A [r_win_room+1]
  STA [draw_room_ret+2]
  JMP draw_room
after_win_room:
  LD_A 0
  STA [DRAW_FLAT]
  JMP main

; ---------------------------------------------------------------------------
; paint_scene: room + enemy (if here & alive) + player. Returns paint_scene_ret.
; ---------------------------------------------------------------------------
paint_scene:
  LD_A 0
  STA [DRAW_FLAT]
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
  JNZ ps_player
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
; draw_hp_bars: redraw player (green) and enemy (red) bars from their HP.
; ---------------------------------------------------------------------------
draw_hp_bars:
  LD_A 90
  STA [BAR_Y]
  LD_A PLAYER_COL
  STA [BAR_COL]
  LD_A [PLAYER_HP]
  STA [BAR_HP]
  LD_A [r_dhb1]
  STA [draw_bar_ret+1]
  LD_A [r_dhb1+1]
  STA [draw_bar_ret+2]
  JMP draw_bar
after_dhb1:
  LD_A 100
  STA [BAR_Y]
  LD_A ENEMY_COLOR
  STA [BAR_COL]
  LD_A [ENEMY_HP]
  STA [BAR_HP]
  LD_A [r_dhb2]
  STA [draw_bar_ret+1]
  LD_A [r_dhb2+1]
  STA [draw_bar_ret+2]
  JMP draw_bar
after_dhb2:
draw_hp_bars_ret:
  JMP 0

; draw_bar(BAR_Y, BAR_COL, BAR_HP): filled BAR_HP px from BAR_X, black remainder
; out to 96 px. Bar is 6 px tall. Returns via draw_bar_ret.
draw_bar:
  LD_A [BAR_HP]
  JNZ db_filled
  JMP db_empty
db_filled:
  LD_A BAR_X
  STA [VX0]
  LD_A [BAR_Y]
  STA [VY]
  LD_A [BAR_HP]
  STA [VW0]
  LD_A 6
  STA [VH]
  LD_A [BAR_COL]
  STA [VCOL]
  LD_A [r_db_f]
  STA [fill_rect_ret+1]
  LD_A [r_db_f+1]
  STA [fill_rect_ret+2]
  JMP fill_rect
after_db_f:
db_empty:
  LD_A [BAR_HP]
  STA [db_ewx+1]
db_ewx:
  LD_X 0
  LD_A FULL_HP
  SUB_A                  ; A = 96 - BAR_HP (empty width)
  STA [BAR_EW]
  JNZ db_do_empty
  JMP draw_bar_ret
db_do_empty:
  LD_A [BAR_HP]
  LD_X BAR_X
  ADD_A                  ; A = BAR_HP + 16 (empty start x)
  STA [VX0]
  LD_A [BAR_Y]
  STA [VY]
  LD_A [BAR_EW]
  STA [VW0]
  LD_A 6
  STA [VH]
  LD_A 0
  STA [VCOL]
  LD_A [r_db_e]
  STA [fill_rect_ret+1]
  LD_A [r_db_e+1]
  STA [fill_rect_ret+2]
  JMP fill_rect
after_db_e:
draw_bar_ret:
  JMP 0

; ---------------------------------------------------------------------------
; draw_battlers: the combat face-off -- green player avatar (left) + red enemy
; avatar (right). Returns via draw_battlers_ret.
; ---------------------------------------------------------------------------
draw_battlers:
  LD_A PAV_COL
  STA [AV_COL]
  LD_A PAV_ROW
  STA [AV_ROW]
  LD_A PLAYER_COL
  STA [AV_COLOR]
  LD_A [r_bat1]
  STA [draw_avatar_ret+1]
  LD_A [r_bat1+1]
  STA [draw_avatar_ret+2]
  JMP draw_avatar
after_bat1:
  LD_A EAV_COL
  STA [AV_COL]
  LD_A EAV_ROW
  STA [AV_ROW]
  LD_A ENEMY_COLOR
  STA [AV_COLOR]
  LD_A [r_bat2]
  STA [draw_avatar_ret+1]
  LD_A [r_bat2+1]
  STA [draw_avatar_ret+2]
  JMP draw_avatar
after_bat2:
draw_battlers_ret:
  JMP 0

; ---------------------------------------------------------------------------
; draw_avatar(AV_COL, AV_ROW, AV_COLOR): fill a 2x2 cell block. Returns via
; draw_avatar_ret. (Four fill_cell calls.)
; ---------------------------------------------------------------------------
draw_avatar:
  LD_A [AV_COL]
  STA [DC_COL]
  LD_A [AV_ROW]
  STA [DC_ROW]
  LD_A [AV_COLOR]
  STA [DC_COLOR]
  LD_A [r_av0]
  STA [fill_cell_ret+1]
  LD_A [r_av0+1]
  STA [fill_cell_ret+2]
  JMP fill_cell
after_av0:
  LD_A [AV_COL]
  LD_X 1
  ADD_A
  STA [DC_COL]
  LD_A [AV_ROW]
  STA [DC_ROW]
  LD_A [AV_COLOR]
  STA [DC_COLOR]
  LD_A [r_av1]
  STA [fill_cell_ret+1]
  LD_A [r_av1+1]
  STA [fill_cell_ret+2]
  JMP fill_cell
after_av1:
  LD_A [AV_COL]
  STA [DC_COL]
  LD_A [AV_ROW]
  LD_X 1
  ADD_A
  STA [DC_ROW]
  LD_A [AV_COLOR]
  STA [DC_COLOR]
  LD_A [r_av2]
  STA [fill_cell_ret+1]
  LD_A [r_av2+1]
  STA [fill_cell_ret+2]
  JMP fill_cell
after_av2:
  LD_A [AV_COL]
  LD_X 1
  ADD_A
  STA [DC_COL]
  LD_A [AV_ROW]
  LD_X 1
  ADD_A
  STA [DC_ROW]
  LD_A [AV_COLOR]
  STA [DC_COLOR]
  LD_A [r_av3]
  STA [fill_cell_ret+1]
  LD_A [r_av3+1]
  STA [fill_cell_ret+2]
  JMP fill_cell
after_av3:
draw_avatar_ret:
  JMP 0

; ---------------------------------------------------------------------------
; draw_room: paint CURROOM map (or DRAW_FLAT colour). Returns draw_room_ret.
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
  STA [DC_COLOR]
  LD_A [DRAW_FLAT]
  JNZ dr_use_flat
  JMP dr_have_col
dr_use_flat:
  STA [DC_COLOR]
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
; draw_player: fill (PCOL,PROW) green. Returns draw_player_ret.
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
; fill_cell(DC_COL, DC_ROW, DC_COLOR): set up an 8x8 rect, then call fill_rect.
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
  LD_A [r_fc_fr]
  STA [fill_rect_ret+1]
  LD_A [r_fc_fr+1]
  STA [fill_rect_ret+2]
  JMP fill_rect
after_fc_fr:
fill_cell_ret:
  JMP 0

; ---------------------------------------------------------------------------
; fill_rect(VX0, VY, VW0, VH, VCOL): fill a rectangle. Returns fill_rect_ret.
; ---------------------------------------------------------------------------
fill_rect:
fr_row:
  LD_A [VY]
  STA [fry+1]
  LD_A [VX0]
  STA [VX]
  LD_A [VW0]
  STA [VW]
fr_col:
  LD_A [VX]
  STA [frx+1]
frx:
  LD_X 0
fry:
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
  JNZ fr_col
  LD_A [VY]
  LD_X 1
  ADD_A
  STA [VY]
  LD_A [VH]
  LD_X 1
  SUB_A
  STA [VH]
  JNZ fr_row
fill_rect_ret:
  JMP 0

; --- subroutine return addresses (little-endian via DW) ---
r_bw_scene: DW after_bw_scene
r_er_scene: DW after_er_scene
r_cw_scene: DW after_cw_scene
r_cf_scene: DW after_cf_scene
r_ce_room:  DW after_ce_room
r_ce_bat:   DW after_ce_bat
r_ce_bars:  DW after_ce_bars
r_cl_room:  DW after_cl_room
r_win_room: DW after_win_room
r_cr_flash: DW after_cr_flash
r_cr_bars1: DW after_cr_bars1
r_cr_restore: DW after_cr_restore
r_cr_bars2: DW after_cr_bars2
r_bat1:     DW after_bat1
r_bat2:     DW after_bat2
r_av0:      DW after_av0
r_av1:      DW after_av1
r_av2:      DW after_av2
r_av3:      DW after_av3
r_ps_room:  DW after_ps_room
r_ps_en:    DW after_ps_en
r_ps_pl:    DW after_ps_pl
r_pdraw:    DW after_pdraw
r_erase:    DW after_erase
r_drcell:   DW after_drcell
r_dp_fill:  DW after_dp_fill
r_dhb1:     DW after_dhb1
r_dhb2:     DW after_dhb2
r_db_f:     DW after_db_f
r_db_e:     DW after_db_e
r_fc_fr:    DW after_fc_fr

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
room3:                      ; hoard room: the gold (tile 2) sits at (6,6)
  DB 1, 1, 1, 1, 1, 1, 1, 1
  DB 1, 0, 0, 0, 0, 0, 0, 1
  DB 1, 0, 1, 1, 1, 1, 0, 1
  DB 0, 0, 0, 0, 0, 0, 0, 1
  DB 1, 0, 1, 1, 1, 1, 0, 1
  DB 1, 0, 0, 0, 0, 0, 0, 1
  DB 1, 0, 0, 0, 0, 0, 2, 1
  DB 1, 1, 1, 1, 1, 1, 1, 1

  ORG $1A00
mul8_data:
  DB 0, 8, 16, 24, 32, 40, 48, 56

  ORG $1C00
tile_col_data:             ; 0 floor grey, 1 wall brick, 2 hoard gold
  DB 5, 4, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0

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
