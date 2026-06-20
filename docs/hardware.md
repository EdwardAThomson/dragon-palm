# Dragon Palm Fantasy Hardware

The Dragon Palm is a fantasy 8-bit handheld with a single 16 KB memory array, three 8-bit CPU registers, a packed 16-colour display, and one input register.

In another Britain, somewhere between bedroom coders, rain-streaked high streets, mail-order tapes, and the smell of warm plastic, the handheld future arrived early.

By 1985, the British games industry had already learned how to do more with less. Tiny machines. Tiny memory. Impossible to match ambition. While the rest of the world was still arguing over what a portable console ought to be, a small Welsh hardware firm looked at a pile of spare components, a battered fantasy paperback, and hummed along to the White Cliffs of Dover, then asked the most dangerous question in British engineering:

*"What can we get away with?"*

The answer was **Dragon Palm**.

It was not elegant. It was not generous. It had one 16 KB memory array, three 8-bit registers, a packed 16-colour display, and one input register that behaved only when it felt like it. Its raw binary cartridges held a mere 8 KB, which meant every sprite, sound, loop, trick, and secret had to fight for its place.

But that was the point.

Dragon Palm was the handheld built by people who thought constraints were not problems. Constraints were part of the game.

It had it's own compact operating system, **DoverOS**, named after the cliffs that supposedly inspired its boot screen. Children swapped carts in playgrounds. Parents called it *"that little dragon thing"*. Programmers called it *"difficult"*. Magazine reviewers called it *"brilliant, in the way that falling down stairs after a couple of pints is memorable"*.

The adverts promised *"proper games in your pocket"*. The manuals promised nothing of the sort. They spoke of registers, screen packing, button states, and *"reasonable conduct near undefined memory"*. The machine did not hide its workings. It dared you to understand them.

In this version of the 1980s, Britain beat the world to handheld gaming by refusing to build a toy. Dragon Palm was a pocket-sized dare. Part console, part puzzle box, part folklore object from a parallel high street where dragons sat beside cassette racks and every game felt like it had been smuggled out of a bedroom at midnight.

It was awkward.

It was clever.

It was *decent enough*.

And for a certain kind of player, that made it **perfect**.

## Memory Map

| Address range | Size | Use |
| --- | ---: | --- |
| `$0000-$1FFF` | 8192 bytes | Program space. Cartridges are loaded here and execution starts at `$0000`. This area is writable, so programs may use self-modifying code. |
| `$2000-$3FFF` | 8192 bytes | VRAM for the 128x128 display. |
| `$4000` | 1 byte | Input register. Reads return the current button bitmask. |

Addresses are 16-bit in instructions, but the reference CPU masks normal memory reads to the 16 KB RAM range. Stores to addresses at or above `$4000` are ignored.

## Display

The screen is 128 pixels wide by 128 pixels high. Each pixel stores a 4-bit colour index, so legal colours are `0-15`.

VRAM starts at `$2000`. Two horizontal pixels are packed into one byte:

| Pixel | Nibble |
| --- | --- |
| Even `x` coordinate | High nibble |
| Odd `x` coordinate | Low nibble |

The byte offset for a pixel is:

```text
$2000 + ((y * 128 + x) >> 1)
```

The packed write is:

```text
even x: byte = (byte & $0F) | (colour << 4)
odd x:  byte = (byte & $F0) | colour
```

The `DRW` instruction is the usual way to draw. It plots one pixel at register coordinates `X,Y` using the lower nibble of `A`. Coordinates outside `0-127` are rejected.

## Input Register

Programs can poll input with either `RDIN` or `LD_A [$4000]`. Both place the current bitmask in `A`.

| Bit | Value | Button |
| ---: | ---: | --- |
| 0 | `1` | Up |
| 1 | `2` | Down |
| 2 | `4` | Left |
| 3 | `8` | Right |
| 4 | `16` | U |
| 5 | `32` | K |
| 6 | `64` | Start |
| 7 | `128` | Pwr |

The CPU only has `JNZ`, so most programs test exact button values by subtracting a constant and branching when the result is not zero:

```asm
  RDIN
  LD_X 1
  SUB_A
  JNZ not_up
  ; Up alone was pressed.
not_up:
```

