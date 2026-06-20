# Dragon Palm Assembly Language

The Dragon Palm CPU has three 8-bit registers:

| Register | Use |
| --- | --- |
| `A` | Accumulator for loads, stores, arithmetic, input, colour values, and `JNZ` tests. |
| `X` | 8-bit X coordinate for `DRW`, also the right-hand operand for `ADD_A` and `SUB_A`. |
| `Y` | 8-bit Y coordinate for `DRW`. |

`PC` is a 16-bit program counter, but cartridge execution wraps inside the `$0000-$1FFF` program area.

## Instruction Reference

| Mnemonic | Opcode | Bytes | Effect |
| --- | ---: | ---: | --- |
| `NOP` | `$00` | 1 | Do nothing. |
| `LD_A nn` | `$01` | 2 | Load immediate byte `nn` into `A`. |
| `LD_A [addr]` | `$02` | 3 | Load byte at `addr` into `A`. `[$4000]` reads input. |
| `STA [addr]` | `$03` | 3 | Store `A` at `addr` if `addr < $4000`. |
| `ADD_A` | `$04` | 1 | `A = (A + X) & $FF`. |
| `SUB_A` | `$05` | 1 | `A = (A - X) & $FF`. |
| `JMP addr` | `$06` | 3 | Set `PC` to `addr`. |
| `JNZ addr` | `$07` | 3 | Set `PC` to `addr` if `A` is not zero. |
| `DRW` | `$08` | 1 | Draw one pixel at `X,Y` using `A & 15`. |
| `RDIN` | `$09` | 1 | Load the input bitmask into `A`. |
| `LD_X nn` | `$0A` | 2 | Load immediate byte `nn` into `X`. |
| `LD_Y nn` | `$0B` | 2 | Load immediate byte `nn` into `Y`. |

## Assembler Syntax

The SDK assembler accepts:

| Syntax | Meaning |
| --- | --- |
| `label:` | Define a label at the current address. |
| `; comment` | Comment to end of line. |
| `$40`, `0x40`, `%0100`, `64` | Hex, hex, binary, or decimal numbers. |
| `[addr]` | Memory operand for `LD_A` and `STA`. |
| `label+1` | Simple label arithmetic. Useful for self-modifying code. |
| `DB 1, 2, 3` | Emit bytes. |
| `DW $2000` | Emit little-endian words. |
| `ORG $0100` | Move the assembly cursor. |

## Draw a Pixel

```asm
start:
  LD_X 64
  LD_Y 64
  LD_A 12
  DRW
forever:
  JMP forever
```

## Move a Drawing Instruction

`LD_X` and `LD_Y` only load immediate values. To move a cursor, rewrite the immediate byte of those instructions:

```asm
draw_x:
  LD_X 64
draw_y:
  LD_Y 64
  LD_A 11
  DRW

  LD_A [draw_x+1]
  LD_X 1
  ADD_A
  STA [draw_x+1]
```

