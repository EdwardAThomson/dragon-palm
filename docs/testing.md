# Dragon Palm Test Suite

Dragon Palm used to be a thing you opened in a browser and judged by eye. The test suite
turns it into a system where **any cartridge's behaviour can be executed, inspected, and
asserted automatically** — no browser, no build step, no dependencies. Run it with:

```sh
node --test        # or: npm test
```

## Headless game execution

The heart of it: the suite can run **any `.dgc` cart exactly as the console would**, entirely
in Node. It loads the cart into the same CPU core that `index.html` ships (this is *proven*,
not assumed — see the fidelity layer below), feeds the input register a scripted button
sequence, runs frames, and reads pixels straight out of VRAM.

```js
const {loadCartFile,run,pixelAt} = require('./tests/harness.js')

const game = loadCartFile('tennis.dgc')   // load a cart, boot screen off
run(game, 5, /* Up held */ 1)             // 5 frames with the Up button down
pixelAt(game, 8, 60)                       // => 6: the paddle moved up
```

`input` can be a constant bitmask or a `frame => bitmask` function, so you can script whole
play sessions ("hold Right for 10 frames, then press U"). `pixelAt(x,y)` decodes the packed
4-bit VRAM; `vramHash()` fingerprints the whole screen for golden-image comparisons.

That single capability — *play a game without a human or a browser* — is what everything else
is built on.

## The four layers

1. **Assembler** (`assembler.test.js`) — every bundled `.asm` reassembles to its committed
   `.dgc` byte-for-byte, plus number bases, `EQU`, `DB`/`DW`, label arithmetic, the
   no-space-in-`[...]` rule, and error cases.
2. **CPU / ISA** (`cpu.test.js`) — each of the 11 opcodes in isolation: arithmetic wrap,
   `JNZ` taken/not-taken, the `STA` ≥ `$4000` guard, input reads, `DRW` nibble packing and
   out-of-range rejection, PC wrap.
3. **Cart functionality** (`carts.test.js`) — the headless-play layer: load a cart, script
   input, assert on the screen ("hold Up → the tennis paddle moves up"). Golden VRAM hashes
   pin the full assemble-and-run pipeline.
4. **Fidelity guard** (`fidelity.test.js`) — proves the harness exercises the *shipping*
   behaviour: it extracts `index.html`'s own cart-loading and pixel-decode logic and runs it
   head-to-head against the harness, and checks the in-process assembler matches the CLI. If
   anyone re-inlines the core, edits the load/render path, or lets the harness drift, this
   fails. So a green suite genuinely means "the browser is correct".

## Why this matters — what it brings to the ecosystem

- **Prove a cart works before swapping it live.** The culture around Dragon Palm is carts as
  currency — pressed into palms, traded on buses (see [cartridge.md](cartridge.md)). Now an
  author can *verify the cart actually plays* before pressing it into circulation, instead of
  shipping vibes.
- **Refactor the emulator with confidence.** The core can change (optimised, extended,
  ported) and the golden hashes + opcode tests catch any behavioural regression instantly.
  This is exactly what made the core extraction safe.
- **CI-ready.** Zero dependencies, deterministic (seeded RNG), and fast — drop `node --test`
  into a workflow and every push is checked.
- **A foundation for tooling.** The shared core + harness are the substrate for a headless
  cart runner (frames → PNG/ASCII), a disassembler, a step-tracer/debugger — each reuses one
  source of truth instead of re-implementing the CPU.
- **AI-assisted cart development.** The `dragon-palm-asm` skill can now *assemble and
  functionally test* the carts it writes — closing the loop from "generate assembly" to
  "demonstrably playable game".

## Harness API

All exported from `tests/harness.js`:

| Function | Purpose |
| --- | --- |
| `loadCart(bytes)` / `loadCartFile(name)` | Load a cart image / a `carts/NAME.dgc` file into a fresh core. |
| `run(core, frames, input)` | Advance `frames` frames; `input` is a bitmask or `frame => bitmask`. |
| `pixelAt(core, x, y)` | Decode the 4-bit colour of one pixel from VRAM. |
| `vramHash(core)` | Stable fingerprint of the whole 8 KB screen. |
| `assemble(text, name)` | Assemble source to an 8192-byte image (throws on error). |
| `DragonPalmCore` | The shared CPU core class itself. |
