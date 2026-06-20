; Magic Screen
; A tiny Etch-a-Sketch cart for Dragon Palm.
; D-pad moves the cursor and every tick paints one pixel.
; U increments the colour. K decrements it.
; The cursor is stored by rewriting the immediate bytes of LD_X and LD_Y.

start:
  LD_A 11
  STA [paint_colour+1]

main:
  ; The CPU has no AND instruction, so each button is tested as an exact
  ; bitmask. Holding more than one drawing control at once is ignored.
  RDIN
  LD_X 1
  SUB_A
  JNZ not_up
  LD_A [draw_y+1]
  LD_X 1
  SUB_A
  STA [draw_y+1]
  JMP paint

not_up:
  RDIN
  LD_X 2
  SUB_A
  JNZ not_down
  LD_A [draw_y+1]
  LD_X 1
  ADD_A
  STA [draw_y+1]
  JMP paint

not_down:
  RDIN
  LD_X 4
  SUB_A
  JNZ not_left
  LD_A [draw_x+1]
  LD_X 1
  SUB_A
  STA [draw_x+1]
  JMP paint

not_left:
  RDIN
  LD_X 8
  SUB_A
  JNZ not_right
  LD_A [draw_x+1]
  LD_X 1
  ADD_A
  STA [draw_x+1]
  JMP paint

not_right:
  ; Colour is the immediate byte inside paint_colour.
  ; DRW only uses the lower nibble, so this can wrap freely.
  RDIN
  LD_X 16
  SUB_A
  JNZ not_u
  LD_A [paint_colour+1]
  LD_X 1
  ADD_A
  STA [paint_colour+1]
  JMP paint

not_u:
  RDIN
  LD_X 32
  SUB_A
  JNZ paint
  LD_A [paint_colour+1]
  LD_X 1
  SUB_A
  STA [paint_colour+1]

paint:
  ; These two immediate bytes are the live cursor position.
draw_x:
  LD_X 64
draw_y:
  LD_Y 64
paint_colour:
  LD_A 11
  DRW

  ; A small busy-wait keeps the sketch speed human.
  LD_A 120
wait:
  LD_X 1
  SUB_A
  JNZ wait
  JMP main
