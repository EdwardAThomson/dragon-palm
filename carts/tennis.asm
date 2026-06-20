; Dragon Tennis
; Up/Down move the left paddle. The right paddle is CPU-controlled.
; Paddles are six pixels long. The loop uses soft clocks instead of a
; blocking wait, keeping controls responsive and reducing erase jitter.

start:
  LD_A 1
  STA [ball_dx]
  STA [ball_dy]
  LD_A 18
  STA [paddle_tick]
  LD_A 22
  STA [ai_tick]
  LD_A 150
  STA [ball_tick]

  LD_X 64
  LD_Y 24
  LD_A 5
  DRW
  LD_X 64
  LD_Y 48
  LD_A 5
  DRW
  LD_X 64
  LD_Y 72
  LD_A 5
  DRW
  LD_X 64
  LD_Y 96
  LD_A 5
  DRW
  JMP draw_all

main:
  LD_A [paddle_tick]
  JNZ paddle_wait
  LD_A 18
  STA [paddle_tick]
  JMP poll_input

paddle_wait:
  LD_A [paddle_tick]
  LD_X 1
  SUB_A
  STA [paddle_tick]
  JMP ai_clock

poll_input:
  RDIN
  LD_X 1
  SUB_A
  JNZ no_up
  JMP player_up

no_up:
  RDIN
  LD_X 2
  SUB_A
  JNZ ai_clock
  JMP player_down

player_up:
  LD_A 0
  STA [move_dir]
  JMP erase_player

player_down:
  LD_A 1
  STA [move_dir]
  JMP erase_player

ai_clock:
  LD_A [ai_tick]
  JNZ ai_wait
  LD_A 22
  STA [ai_tick]
  JMP ai_step

ai_wait:
  LD_A [ai_tick]
  LD_X 1
  SUB_A
  STA [ai_tick]
  JMP ball_clock

ball_clock:
  LD_A [ball_tick]
  JNZ ball_wait
  LD_A 150
  STA [ball_tick]
  JMP ball_update

ball_wait:
  LD_A [ball_tick]
  LD_X 1
  SUB_A
  STA [ball_tick]
  JMP main

erase_player:
  LD_X 8
paddle_e0:
  LD_Y 61
  LD_A 0
  DRW
  LD_X 8
paddle_e1:
  LD_Y 62
  LD_A 0
  DRW
  LD_X 8
paddle_e2:
  LD_Y 63
  LD_A 0
  DRW
  LD_X 8
paddle_e3:
  LD_Y 64
  LD_A 0
  DRW
  LD_X 8
paddle_e4:
  LD_Y 65
  LD_A 0
  DRW
  LD_X 8
paddle_e5:
  LD_Y 66
  LD_A 0
  DRW

  LD_A [move_dir]
  JNZ do_player_down

  LD_A [paddle_e0+1]
  LD_X 1
  SUB_A
  STA [paddle_e0+1]
  STA [paddle_d0+1]
  LD_A [paddle_e1+1]
  LD_X 1
  SUB_A
  STA [paddle_e1+1]
  STA [paddle_d1+1]
  LD_A [paddle_e2+1]
  LD_X 1
  SUB_A
  STA [paddle_e2+1]
  STA [paddle_d2+1]
  LD_A [paddle_e3+1]
  LD_X 1
  SUB_A
  STA [paddle_e3+1]
  STA [paddle_d3+1]
  LD_A [paddle_e4+1]
  LD_X 1
  SUB_A
  STA [paddle_e4+1]
  STA [paddle_d4+1]
  LD_A [paddle_e5+1]
  LD_X 1
  SUB_A
  STA [paddle_e5+1]
  STA [paddle_d5+1]
  JMP draw_player

do_player_down:
  LD_A [paddle_e0+1]
  LD_X 1
  ADD_A
  STA [paddle_e0+1]
  STA [paddle_d0+1]
  LD_A [paddle_e1+1]
  LD_X 1
  ADD_A
  STA [paddle_e1+1]
  STA [paddle_d1+1]
  LD_A [paddle_e2+1]
  LD_X 1
  ADD_A
  STA [paddle_e2+1]
  STA [paddle_d2+1]
  LD_A [paddle_e3+1]
  LD_X 1
  ADD_A
  STA [paddle_e3+1]
  STA [paddle_d3+1]
  LD_A [paddle_e4+1]
  LD_X 1
  ADD_A
  STA [paddle_e4+1]
  STA [paddle_d4+1]
  LD_A [paddle_e5+1]
  LD_X 1
  ADD_A
  STA [paddle_e5+1]
  STA [paddle_d5+1]
  JMP draw_player

ball_update:
erase_ball_x:
  LD_X 64
erase_ball_y:
  LD_Y 64
  LD_A 0
  DRW

  LD_A [erase_ball_x+1]
  LD_X 122
  SUB_A
  JNZ not_ai_miss
  JMP player_scores

not_ai_miss:
  LD_A [erase_ball_x+1]
  LD_X 5
  SUB_A
  JNZ not_player_miss
  JMP ai_scores

not_player_miss:
  LD_A [erase_ball_x+1]
  LD_X 9
  SUB_A
  JNZ check_ai_paddle
  JMP left_y0

check_ai_paddle:
  LD_A [erase_ball_x+1]
  LD_X 118
  SUB_A
  JNZ wall_y
  JMP right_y0

left_y0:
  LD_A [paddle_e0+1]
  STA [cmp_left_y0+1]
  LD_A [erase_ball_y+1]
cmp_left_y0:
  LD_X 61
  SUB_A
  JNZ left_y1
  JMP bounce_right

left_y1:
  LD_A [paddle_e1+1]
  STA [cmp_left_y1+1]
  LD_A [erase_ball_y+1]
cmp_left_y1:
  LD_X 62
  SUB_A
  JNZ left_y2
  JMP bounce_right

left_y2:
  LD_A [paddle_e2+1]
  STA [cmp_left_y2+1]
  LD_A [erase_ball_y+1]
cmp_left_y2:
  LD_X 63
  SUB_A
  JNZ left_y3
  JMP bounce_right

left_y3:
  LD_A [paddle_e3+1]
  STA [cmp_left_y3+1]
  LD_A [erase_ball_y+1]
cmp_left_y3:
  LD_X 64
  SUB_A
  JNZ left_y4
  JMP bounce_right

left_y4:
  LD_A [paddle_e4+1]
  STA [cmp_left_y4+1]
  LD_A [erase_ball_y+1]
cmp_left_y4:
  LD_X 65
  SUB_A
  JNZ left_y5
  JMP bounce_right

left_y5:
  LD_A [paddle_e5+1]
  STA [cmp_left_y5+1]
  LD_A [erase_ball_y+1]
cmp_left_y5:
  LD_X 66
  SUB_A
  JNZ wall_y

bounce_right:
  LD_A 1
  STA [ball_dx]
  JMP wall_y

right_y0:
  LD_A [ai_e0+1]
  STA [cmp_right_y0+1]
  LD_A [erase_ball_y+1]
cmp_right_y0:
  LD_X 61
  SUB_A
  JNZ right_y1
  JMP bounce_left

right_y1:
  LD_A [ai_e1+1]
  STA [cmp_right_y1+1]
  LD_A [erase_ball_y+1]
cmp_right_y1:
  LD_X 62
  SUB_A
  JNZ right_y2
  JMP bounce_left

right_y2:
  LD_A [ai_e2+1]
  STA [cmp_right_y2+1]
  LD_A [erase_ball_y+1]
cmp_right_y2:
  LD_X 63
  SUB_A
  JNZ right_y3
  JMP bounce_left

right_y3:
  LD_A [ai_e3+1]
  STA [cmp_right_y3+1]
  LD_A [erase_ball_y+1]
cmp_right_y3:
  LD_X 64
  SUB_A
  JNZ right_y4
  JMP bounce_left

right_y4:
  LD_A [ai_e4+1]
  STA [cmp_right_y4+1]
  LD_A [erase_ball_y+1]
cmp_right_y4:
  LD_X 65
  SUB_A
  JNZ right_y5
  JMP bounce_left

right_y5:
  LD_A [ai_e5+1]
  STA [cmp_right_y5+1]
  LD_A [erase_ball_y+1]
cmp_right_y5:
  LD_X 66
  SUB_A
  JNZ wall_y

bounce_left:
  LD_A 0
  STA [ball_dx]

wall_y:
  LD_A [erase_ball_y+1]
  LD_X 122
  SUB_A
  JNZ not_bottom
  LD_A 0
  STA [ball_dy]

not_bottom:
  LD_A [erase_ball_y+1]
  LD_X 5
  SUB_A
  JNZ move_ball_x
  LD_A 1
  STA [ball_dy]
  JMP move_ball_x

ai_step:
  LD_A [ball_dy]
  JNZ ai_down_check
  LD_A [ai_e0+1]
  LD_X 5
  SUB_A
  JNZ ai_up_ok
  JMP ball_clock

ai_up_ok:
  LD_A 0
  STA [ai_dir]
  JMP erase_ai

ai_down_check:
  LD_A [ai_e5+1]
  LD_X 122
  SUB_A
  JNZ ai_down_ok
  JMP ball_clock

ai_down_ok:
  LD_A 1
  STA [ai_dir]
  JMP erase_ai

erase_ai:
  LD_X 119
ai_e0:
  LD_Y 61
  LD_A 0
  DRW
  LD_X 119
ai_e1:
  LD_Y 62
  LD_A 0
  DRW
  LD_X 119
ai_e2:
  LD_Y 63
  LD_A 0
  DRW
  LD_X 119
ai_e3:
  LD_Y 64
  LD_A 0
  DRW
  LD_X 119
ai_e4:
  LD_Y 65
  LD_A 0
  DRW
  LD_X 119
ai_e5:
  LD_Y 66
  LD_A 0
  DRW

  LD_A [ai_dir]
  JNZ ai_down
  LD_A [ai_e0+1]
  LD_X 1
  SUB_A
  STA [ai_e0+1]
  STA [ai_d0+1]
  LD_A [ai_e1+1]
  LD_X 1
  SUB_A
  STA [ai_e1+1]
  STA [ai_d1+1]
  LD_A [ai_e2+1]
  LD_X 1
  SUB_A
  STA [ai_e2+1]
  STA [ai_d2+1]
  LD_A [ai_e3+1]
  LD_X 1
  SUB_A
  STA [ai_e3+1]
  STA [ai_d3+1]
  LD_A [ai_e4+1]
  LD_X 1
  SUB_A
  STA [ai_e4+1]
  STA [ai_d4+1]
  LD_A [ai_e5+1]
  LD_X 1
  SUB_A
  STA [ai_e5+1]
  STA [ai_d5+1]
  JMP draw_ai

ai_down:
  LD_A [ai_e0+1]
  LD_X 1
  ADD_A
  STA [ai_e0+1]
  STA [ai_d0+1]
  LD_A [ai_e1+1]
  LD_X 1
  ADD_A
  STA [ai_e1+1]
  STA [ai_d1+1]
  LD_A [ai_e2+1]
  LD_X 1
  ADD_A
  STA [ai_e2+1]
  STA [ai_d2+1]
  LD_A [ai_e3+1]
  LD_X 1
  ADD_A
  STA [ai_e3+1]
  STA [ai_d3+1]
  LD_A [ai_e4+1]
  LD_X 1
  ADD_A
  STA [ai_e4+1]
  STA [ai_d4+1]
  LD_A [ai_e5+1]
  LD_X 1
  ADD_A
  STA [ai_e5+1]
  STA [ai_d5+1]

draw_ai:
  LD_X 119
ai_d0:
  LD_Y 61
  LD_A 6
  DRW
  LD_X 119
ai_d1:
  LD_Y 62
  LD_A 6
  DRW
  LD_X 119
ai_d2:
  LD_Y 63
  LD_A 6
  DRW
  LD_X 119
ai_d3:
  LD_Y 64
  LD_A 6
  DRW
  LD_X 119
ai_d4:
  LD_Y 65
  LD_A 6
  DRW
  LD_X 119
ai_d5:
  LD_Y 66
  LD_A 6
  DRW
  JMP ball_clock

move_ball_x:
  LD_A [ball_dx]
  JNZ move_right
  LD_A [erase_ball_x+1]
  LD_X 1
  SUB_A
  STA [erase_ball_x+1]
  STA [draw_ball_x+1]
  JMP move_ball_y

move_right:
  LD_A [erase_ball_x+1]
  LD_X 1
  ADD_A
  STA [erase_ball_x+1]
  STA [draw_ball_x+1]

move_ball_y:
  LD_A [ball_dy]
  JNZ move_down
  LD_A [erase_ball_y+1]
  LD_X 1
  SUB_A
  STA [erase_ball_y+1]
  STA [draw_ball_y+1]
  JMP draw_ball

move_down:
  LD_A [erase_ball_y+1]
  LD_X 1
  ADD_A
  STA [erase_ball_y+1]
  STA [draw_ball_y+1]
  JMP draw_ball

player_scores:
player_score_x:
  LD_X 14
  LD_Y 8
  LD_A 11
  DRW
  LD_A [player_score_x+1]
  LD_X 2
  ADD_A
  STA [player_score_x+1]
  LD_A 64
  STA [erase_ball_x+1]
  STA [draw_ball_x+1]
  STA [erase_ball_y+1]
  STA [draw_ball_y+1]
  LD_A 0
  STA [ball_dx]
  LD_A 1
  STA [ball_dy]
  JMP draw_ball

ai_scores:
ai_score_x:
  LD_X 114
  LD_Y 8
  LD_A 14
  DRW
  LD_A [ai_score_x+1]
  LD_X 2
  SUB_A
  STA [ai_score_x+1]
  LD_A 64
  STA [erase_ball_x+1]
  STA [draw_ball_x+1]
  STA [erase_ball_y+1]
  STA [draw_ball_y+1]
  LD_A 1
  STA [ball_dx]
  STA [ball_dy]
  JMP draw_ball

draw_all:
  JMP draw_player_start

draw_player:
  LD_X 8
paddle_d0:
  LD_Y 61
  LD_A 6
  DRW
  LD_X 8
paddle_d1:
  LD_Y 62
  LD_A 6
  DRW
  LD_X 8
paddle_d2:
  LD_Y 63
  LD_A 6
  DRW
  LD_X 8
paddle_d3:
  LD_Y 64
  LD_A 6
  DRW
  LD_X 8
paddle_d4:
  LD_Y 65
  LD_A 6
  DRW
  LD_X 8
paddle_d5:
  LD_Y 66
  LD_A 6
  DRW
  JMP ai_clock

draw_player_start:
  LD_X 8
  LD_Y 61
  LD_A 6
  DRW
  LD_X 8
  LD_Y 62
  LD_A 6
  DRW
  LD_X 8
  LD_Y 63
  LD_A 6
  DRW
  LD_X 8
  LD_Y 64
  LD_A 6
  DRW
  LD_X 8
  LD_Y 65
  LD_A 6
  DRW
  LD_X 8
  LD_Y 66
  LD_A 6
  DRW
  LD_X 119
  LD_Y 61
  LD_A 6
  DRW
  LD_X 119
  LD_Y 62
  LD_A 6
  DRW
  LD_X 119
  LD_Y 63
  LD_A 6
  DRW
  LD_X 119
  LD_Y 64
  LD_A 6
  DRW
  LD_X 119
  LD_Y 65
  LD_A 6
  DRW
  LD_X 119
  LD_Y 66
  LD_A 6
  DRW
  JMP draw_ball

draw_ball:
draw_ball_x:
  LD_X 64
draw_ball_y:
  LD_Y 64
  LD_A 15
  DRW
  JMP main

ball_dx:
  DB 1
ball_dy:
  DB 1
ai_tick:
  DB 0
ai_dir:
  DB 0
move_dir:
  DB 0
paddle_tick:
  DB 0
ball_tick:
  DB 0
