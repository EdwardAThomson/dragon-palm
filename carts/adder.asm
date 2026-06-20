; Adder
; A fixed-length Snake-style demonstration for Dragon Palm.
; The body is an unrolled chain of self-modifying LD_X and LD_Y operands.
; Eating the treat moves it and reduces the delay seed, so the game starts
; slow and becomes faster after successful bites.

start:
  LD_A 3
  STA [direction]

main:
  RDIN
  LD_X 1
  SUB_A
  JNZ no_up
  LD_A 0
  STA [direction]
  JMP tick

no_up:
  RDIN
  LD_X 2
  SUB_A
  JNZ no_down
  LD_A 1
  STA [direction]
  JMP tick

no_down:
  RDIN
  LD_X 4
  SUB_A
  JNZ no_left
  LD_A 2
  STA [direction]
  JMP tick

no_left:
  RDIN
  LD_X 8
  SUB_A
  JNZ tick
  LD_A 3
  STA [direction]

tick:
erase_tail_x:
  LD_X 56
erase_tail_y:
  LD_Y 64
  LD_A 0
  DRW

  LD_A [seg4_x+1]
  STA [erase_tail_x+1]
  LD_A [seg4_y+1]
  STA [erase_tail_y+1]

  LD_A [seg3_x+1]
  STA [seg4_x+1]
  LD_A [seg3_y+1]
  STA [seg4_y+1]

  LD_A [seg2_x+1]
  STA [seg3_x+1]
  LD_A [seg2_y+1]
  STA [seg3_y+1]

  LD_A [seg1_x+1]
  STA [seg2_x+1]
  LD_A [seg1_y+1]
  STA [seg2_y+1]

  LD_A [head_x+1]
  STA [seg1_x+1]
  LD_A [head_y+1]
  STA [seg1_y+1]

  LD_A [direction]
  JNZ check_down
  LD_A [head_y+1]
  LD_X 1
  SUB_A
  STA [head_y+1]
  JMP check_eat

check_down:
  LD_A [direction]
  LD_X 1
  SUB_A
  JNZ check_left
  LD_A [head_y+1]
  LD_X 1
  ADD_A
  STA [head_y+1]
  JMP check_eat

check_left:
  LD_A [direction]
  LD_X 2
  SUB_A
  JNZ move_right
  LD_A [head_x+1]
  LD_X 1
  SUB_A
  STA [head_x+1]
  JMP check_eat

move_right:
  LD_A [head_x+1]
  LD_X 1
  ADD_A
  STA [head_x+1]

check_eat:
  ; LD_X cannot read memory, so copy the treat coordinate into the compare
  ; instruction's immediate operand before subtracting.
  LD_A [treat_x+1]
  STA [cmp_treat_x+1]
  LD_A [head_x+1]
cmp_treat_x:
  LD_X 96
  SUB_A
  JNZ draw

  LD_A [treat_y+1]
  STA [cmp_treat_y+1]
  LD_A [head_y+1]
cmp_treat_y:
  LD_X 64
  SUB_A
  JNZ draw

eat:
score_x:
  LD_X 4
  LD_Y 4
  LD_A 12
  DRW
  LD_A [score_x+1]
  LD_X 2
  ADD_A
  STA [score_x+1]

  LD_A [delay_seed]
  LD_X 4
  SUB_A
  JNZ speed_up
  JMP move_treat

speed_up:
  LD_A [delay_seed]
  LD_X 1
  SUB_A
  STA [delay_seed]

move_treat:
  LD_A [treat_x+1]
  LD_X 112
  SUB_A
  JNZ treat_x_step
  LD_A 16
  STA [treat_x+1]
  JMP move_treat_y

treat_x_step:
  LD_A [treat_x+1]
  LD_X 16
  ADD_A
  STA [treat_x+1]

move_treat_y:
  LD_A [treat_y+1]
  LD_X 112
  SUB_A
  JNZ treat_y_step
  LD_A 16
  STA [treat_y+1]
  JMP draw

treat_y_step:
  LD_A [treat_y+1]
  LD_X 8
  ADD_A
  STA [treat_y+1]

draw:
seg4_x:
  LD_X 56
seg4_y:
  LD_Y 64
  LD_A 3
  DRW
seg3_x:
  LD_X 58
seg3_y:
  LD_Y 64
  LD_A 3
  DRW
seg2_x:
  LD_X 60
seg2_y:
  LD_Y 64
  LD_A 11
  DRW
seg1_x:
  LD_X 62
seg1_y:
  LD_Y 64
  LD_A 11
  DRW
head_x:
  LD_X 64
head_y:
  LD_Y 64
  LD_A 12
  DRW

treat_x:
  LD_X 96
treat_y:
  LD_Y 64
  LD_A 14
  DRW

  LD_A [delay_seed]
  STA [delay_count]
wait_outer:
  RDIN
  LD_X 1
  SUB_A
  JNZ wait_no_up
  LD_A 0
  STA [direction]
  JMP wait_poll_done

wait_no_up:
  RDIN
  LD_X 2
  SUB_A
  JNZ wait_no_down
  LD_A 1
  STA [direction]
  JMP wait_poll_done

wait_no_down:
  RDIN
  LD_X 4
  SUB_A
  JNZ wait_no_left
  LD_A 2
  STA [direction]
  JMP wait_poll_done

wait_no_left:
  RDIN
  LD_X 8
  SUB_A
  JNZ wait_poll_done
  LD_A 3
  STA [direction]

wait_poll_done:
  LD_A 255
wait_inner:
  LD_X 1
  SUB_A
  JNZ wait_inner
  LD_A [delay_count]
  LD_X 1
  SUB_A
  STA [delay_count]
  JNZ wait_outer
  JMP main

direction:
  DB 3
delay_seed:
  DB 12
delay_count:
  DB 0
