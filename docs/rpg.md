# Dragon Palm RPG: Design Doc

A scoping/architecture doc for a tile-based RPG on the Dragon Palm. On this machine
the memory layout *is* the game, so this doc fixes the budget, the data formats, and
the core code idioms before a line of the cart is written.

Genre target: **Zelda 1 dungeon + Dragon Warrior combat**, not Final Fantasy. A
flip-screen dungeon you walk through, wall collision, bump-to-fight turn-based combat
with numeric HP, and a goal room (the dragon's hoard). Working title: **Dragon Quest
for the Hoard** (reuses the `hoard` cart's theme and movement engine).

---

## 1. The hardware budget (the numbers that bind)

| Resource | Value | Consequence |
| --- | --- | --- |
| Program space `$0000-$1FFF` | 8192 bytes | Holds **all** code *and* data *and* mutable variables. The real ceiling. |
| VRAM `$2000-$3FFF` | 8192 bytes | 128×128, 16 colours, 2 px/byte. Persists across frames (draw once, leave it). |
| Input `$4000` | 1 byte | Button bitmask. Read-only. |
| Instruction budget | ~500 instr/frame × ~60 fps = **~30,000 instr/sec** | A naive full-screen redraw costs ~0.7 s. Never redraw per frame. |
| Opcodes | 12 | No `CALL`/`RET`, no indexing, no multiply. |
| **No carry/borrow flag** | — | Ordered compares (`≤`, `<`) can't be done in one subtract. |
| **No bitwise ops** | — | No `AND`/`OR`/`XOR`. Bit tests must be done by subtraction. |

There is **no separate work RAM**. Game state variables live in program space and are
written with `STA`. Reserve a block for them (see §5).

---

## 2. Core code idioms

These four patterns carry the entire engine. Get them right and the rest is content.

### 2a. Table indexing — self-modify the operand, page-align the table

There is no indexed addressing. To read `tile[N]` from a room map, patch the low byte of
a `LD_A [addr]` operand. **Keep every table 256-byte page-aligned** (`ORG $xx00`) so the
index *is* the low byte and there is no 16-bit carry to handle:

```asm
; read room_map[N] into A, where N is in A
  STA [rd+1]          ; patch low operand byte with the index
rd:
  LD_A [room_map]     ; room_map must be at $xx00; assembles as LD_A $xx00,
                      ; the +1 byte (the $00) is now N
```

`room_map` aligned to a page means `room_map+1` holds the low address byte; writing `N`
there makes the load read `room_map + N`. No add, no carry. This is THE idiom.

### 2b. Fake subroutine — patch the return JMP

No stack. A shared routine (e.g. `draw_tile`, `blit`) ends with a `JMP` whose operand the
caller patches with the return address. One return slot per routine; keep call graphs flat
(no recursion, avoid nesting the same routine inside itself).

```asm
; caller:
  LD_A <ret_lo>
  STA [draw_tile_ret+1]
  LD_A <ret_hi>
  STA [draw_tile_ret+2]
  JMP draw_tile
ret_point:
  ...

draw_tile:
  ...
draw_tile_ret:
  JMP $0000          ; operand patched by caller before the call
```

Most of the game is better written as a **flat state machine** (one `JMP`-dispatched loop,
states = EXPLORE / COMBAT / GAMEOVER) and only the genuinely shared blit code uses this.

### 2c. Equality and "did it hit zero" — `SUB_A` then `JNZ`

`JNZ` is the only branch; it tests whether `A` is non-zero. Equality is a subtract:

```asm
  LD_A [val]
  LD_X 7
  SUB_A              ; A = val - 7
  JNZ not_seven      ; taken unless val == 7
```

### 2d. Ordered compare (`≤`, `<`) — count down, because there is no borrow flag

`SUB_A` wraps mod 256 and sets no flag, so `hp - damage` can't tell you whether `damage`
exceeded `hp`. **Resolve ordering by decrementing one point at a time with a zero-test
before each step.** This is why combat keeps HP and damage small (see §7).

```asm
; subtract X damage from [hp], clamping at 0, branching to `dead` if it reaches 0
take_hit:
  LD_A [dmg]         ; remaining damage to apply
  JNZ apply          ; nothing left to apply -> survived
  JMP survived
apply:
  LD_A [hp]
  JNZ dec_hp         ; hp already 0 -> dead
  JMP dead
dec_hp:
  LD_X 1
  SUB_A
  STA [hp]
  JNZ dec_dmg        ; hp hit 0 -> dead
  JMP dead
dec_dmg:
  LD_A [dmg]
  LD_X 1
  SUB_A
  STA [dmg]
  JMP take_hit
```

Same principle for "is A ≥ 128" / bit-7 tests: you can't `AND $80`, so either keep values
in a range where a single `SUB` + zero-test suffices, or count.

---

## Palette reference (colour index → on-screen colour)

The host stores palette entries little-endian as `0xAABBGGRR`, so read the bytes
**low-to-high = R, G, B**. The actual 16 colours (from `index.html`):

| Idx | Colour | Idx | Colour | Idx | Colour | Idx | Colour |
| --: | --- | --: | --- | --: | --- | --: | --- |
| 0 | black | 4 | rust/red-brown | 8 | **red** (255,0,77) | 12 | light blue |
| 1 | dark navy | 5 | grey | 9 | orange | 13 | mauve |
| 2 | purple/magenta | 6 | light grey (≈white) | 10 | yellow | 14 | pink |
| 3 | green (mid) | 7 | white | 11 | **bright green** | 15 | pale peach |

RPG conventions: HUD frame = 6, player HP/sprite = 11 (green), enemy HP = 8 (red),
gold/treasure = 9 or 10. Floor/wall tiles pick from 1/4/5 (earthy) in M2.

---

## 3. Rendering strategy

VRAM persists, so the model is **draw the room once on entry, then each frame only erase
and redraw the moving things** (player, one enemy). This is exactly the `hoard` cart's
trailing-edge-erase movement.

### Transition cost

A room flip repaints the play area. Cost ≈ `pixels × ~3 instr/px ÷ 30,000 instr/sec`
(the ~3 covers the per-pixel `LD_X`/`DRW` plus tile-loop overhead):

| Play area | Pixels | Approx flip time |
| --- | ---: | ---: |
| 128×128 full screen | 16384 | ~1.6 s (too slow) |
| 96×96 viewport | 9216 | ~0.9 s |
| 64×64 viewport | 4096 | ~0.4 s |
| 48×48 viewport | 2304 | ~0.23 s |

**Decision: use a 64×64 viewport** for the play field with a static HUD frame drawn once at
boot. A ~0.4 s repaint reads as a deliberate retro screen-wipe, not lag. (Embracing a
full-screen wipe is a valid alternative aesthetic, but the small viewport keeps flips snappy
and frees VRAM for a persistent HUD.)

Per-frame player movement (erase old 8×8 cell, draw new) is a few dozen instructions —
trivially within budget.

---

## 4. Tiles and rooms

- **Tile:** 8×8 pixels, one of 16 tile types (4-bit id).
- **Room:** 8×8 tiles = the 64×64 viewport. 64 tiles/room.
- **Map storage:** **unpacked, 1 byte per tile = 64 bytes per room** (page-aligned, §2a).
  Nibble-packing (32 B/room) was the original plan, but the CPU has **no shift and no AND
  opcode**, so unpacking a nibble at runtime costs a divide-by-16 loop per read. At 64 B/room
  a 16-room dungeon is 1 KB, trivial against the headroom, so we trade the bytes for simple,
  fast O(1) tile reads. Index a tile as `room[MUL8[row] + col]` using a small `MUL8` table
  (since there is no multiply either).
- **Tile attributes:** a 16-entry table mapping tile id → {solid?, colour, is-door,
  is-encounter}. 16 bytes. Solidity drives collision; everything else drives render/logic.

Collision: compute the target tile's index from the player's intended (x,y), read its id
(§2a), look up `solid?` in the attribute table, block the move if solid.

---

## 5. Memory map (program space `$0000-$1FFF`)

Illustrative budget; real addresses come from assembler labels. The point is that it *fits*.

| Range | Size | Use |
| --- | ---: | --- |
| `$0000-$00FF` | 256 B | Boot/init + main state-machine dispatch |
| `$0100-$0AFF` | 2.5 KB | Engine: input, movement, collision, blit, combat, HUD |
| `$0B00-$0CFF` | 512 B | Tile-pattern data (16 tiles × 8×8 × 4bpp = 32 B/tile) |
| `$0D00-$0EFF` | 512 B | Room maps (≤16 rooms × 32 B), page-aligned |
| `$0F00-$0FFF` | 256 B | Entity table (per-room enemy placements) + enemy stat table |
| `$1000-$1DFF` | 3.5 KB | Headroom: more rooms, a tiny font, more enemy types, etc. |
| `$1F00-$1FFF` | 256 B | **Mutable variables / scratch** (player x/y, hp, atk, room id, state, dmg, rng) |

Numbers above are a starting allocation, not a contract. Total comfortably under 8 KB with
room to grow.

---

## 6. Game state machine

One dispatch loop driven by a `state` byte in the variable page:

- **EXPLORE** — poll input, attempt move, collision-check, redraw player; on stepping onto
  an encounter tile (or touching an enemy entity) → set state COMBAT, paint combat screen.
- **COMBAT** — turn-based: player attacks (damage to enemy), enemy counterattacks (damage to
  player), update HUD numbers; enemy hp 0 → loot/return to EXPLORE; player hp 0 → GAMEOVER.
- **GAMEOVER / WIN** — static screen, wait for Start to reset.

Room flips happen inside EXPLORE: walking off a viewport edge sets `room id` to the neighbour
(from a per-room exit table) and repaints the room.

---

## 7. Combat model

All stats are bytes in the variable page, kept **small** so the count-down compare (§2d) is
cheap and unambiguous:

| Stat | Range | Notes |
| --- | ---: | --- |
| Player HP | 0–30 | Displayed as a number or a 30-px bar in the HUD |
| Player ATK | 1–9 | Damage dealt per hit |
| Enemy HP | 0–20 | Per enemy type |
| Enemy ATK | 1–6 | Per enemy type |

- **Attack:** `enemy_hp = enemy_hp - player_atk` via the §2d clamp-and-detect loop. Reaches
  0 → enemy dies, return to map (optionally mark that entity cleared for the session).
- **Counterattack:** `player_hp = player_hp - enemy_atk` the same way; 0 → GAMEOVER.
- **Randomness (optional):** no RNG opcode. Use a 1-byte LFSR-ish counter advanced each frame
  (`seed = seed + X` with a changing X, or fold in the input byte) to vary damage ±1. Keep it
  cheap; determinism is fine for an MVP.
- **No floats, no multiply:** XP→level growth (stretch goal) is table-driven (level → atk/maxhp
  lookup), not computed.

HUD display (decided, §11): HP shown as **pixel bars**, not digits — a bar is just a run of
coloured pixels whose length tracks HP, cheap to draw and re-draw, and needs no font. The MVP
is therefore entirely text-free (see §9).

---

## 8. Input

The input byte is a bitmask but there are no bitwise ops, so test the way `hardware.md` shows:
`RDIN`, then `SUB_A` an exact button value and `JNZ`. One button at a time is clean; a diagonal
is the *sum* of two bits, which the count-down/compare handles. For the MVP, treat movement as
4-directional and read exact values (Up=1, Down=2, Left=4, Right=8, U=16=attack/confirm,
Start=64=reset). Debounce by remembering last frame's input in the variable page.

---

## 9. The one real enemy: text

There is no font ROM; every glyph is hand-drawn pixels, costing memory and frame budget.

**MVP rule: icon + bar UI, zero text.** HP is shown as pixel bars (§7), not digits, so the MVP
needs no font at all. No dialogue, no item names. A 3×5 digit font and a handful of words (e.g.
"WIN", item glyphs) are *stretch goals*, not a foundation. Story is conveyed through rooms,
tiles, and the goal — not sentences.

---

## 10. Scope and milestones

### MVP — one completable loop
1. ✅ **Boot + viewport + HUD frame** drawn once; state machine skeleton. (`carts/rpg.asm`)
2. ✅ **Walk a single room** with wall collision (grid-step movement + tile lookup).
3. ✅ **Room flips** between 4 rooms through doorways; repaint on entry. (Linear chain,
   CURROOM = room page byte, so neighbours are +/-1 page; no exit table needed.)
4. ✅ **One enemy** entity (red cell on room 1's door row); stepping onto it triggers COMBAT.
   Placeholder combat screen + Start to flee; real fight is M5.
5. ✅ **Turn-based combat**: U attacks, HP bars drain (HP stored directly as bar-pixel
   width, so no scaling/multiply); win clears the enemy and opens the path, lose = GAMEOVER
   (Start resets). Damage divides HP evenly so it lands on 0 (no borrow-flag needed).
   Combat screen is a green-vs-red **face-off** with a white **hit-flash** so it reads
   without text (green/red HP bars map to the two avatars).
6. ✅ **Goal room:** a gold **hoard tile** (id 2) in room 3; stepping on it = WIN screen
   (gold field, Start resets). `tests/rpg.test.js` includes a full end-to-end playthrough.

**MVP complete.** Boot → explore a 4-room dungeon → beat the guard → cross to the hoard → win.
61/61 tests pass.

**Known perf caveat (M3-M5):** every room/combat repaint flat-fills cells via `DRW`
(~2.5 s for a full viewport, ~0.5 s per HP-bar update). Functionally fine, reads as a
retro screen-load, but the obvious optimisation is direct VRAM byte-writes (2 px/byte)
instead of per-pixel `DRW`. Deferred until it actually bothers play.

Each milestone is a runnable `.dgc` and gets a headless test (load cart, script input, assert
VRAM via `pixelAt`) so the build stays honest against the conformance laws.

### Stretch
- Keys + locked doors (item flags as bytes).
- 2–3 enemy types (stat table rows).
- XP → level growth (table-driven).
- A tiny word font; minimal SFX via... (Dragon Palm has no audio opcode — flash-frame "effects" only).
- Larger world (more page-aligned rooms in the `$1000` headroom).

---

## 11. Decisions (settled 2026-06-25)

- **Viewport size:** ✅ **64×64** (~0.4 s flips, static HUD frame).
- **Combat trigger:** ✅ **fixed enemy entities** (Zelda-style). No RNG needed for encounters.
- **Persistence:** ✅ **cleared enemies stay cleared for the session** (1 flag bit/entity).
- **HP display:** ✅ **pixel bars** for both player and enemy. No digit font in the MVP, which
  keeps the build entirely text-free (§9).

---

## Constraints this design must never break (see `hardware-is-gospel`)

No opcodes outside the 12. No memory access outside the map. No writes at/above `$4000`.
Colours masked to 4 bits. Draw coords clipped to 0–127. PC wraps in `$0000-$1FFF`. The RPG
lives entirely inside these laws — that is the point of the machine.
