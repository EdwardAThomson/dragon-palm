# Plan: Extract the Dragon Palm Core + a Headless Test Suite

**Status:** Approved — Option A (classic shared script); all three test layers in the first increment.
**Date:** 2026-06-21
**Scope:** Extract the CPU core to a shared module (no behaviour changes), then build a
Node-based test suite on top of it. The test suite — not the refactor — is the deliverable;
the extraction is its prerequisite.

The test suite runs **headlessly in Node, never in the browser**. Its purpose is to let an
author *demonstrate a cart is correct and does what it should before pushing it live*. For
that to be meaningful, the tests must run the **same core that ships in `index.html`** — a
separate Node-only copy could silently drift, so a single shared core is the foundation.

## Motivation

The entire emulator — CPU, memory, renderer, input, audio, cartridge loader — currently
lives inline in `index.html` as ~130 lines of deliberately golfed JavaScript. That is
perfect for the project's core promise (*open one file in a browser, zero build*) but it
makes the CPU impossible to reuse: it cannot be imported, unit-tested, run headlessly, or
shared with future tooling.

Extracting the CPU core into a standalone module unlocks:

- **Headless execution** — run a cart in Node for CI, snapshots, and fuzzing.
- **Tooling reuse** — a disassembler, debugger, step-tracer, or cart runner can all share
  one CPU instead of re-implementing `step()`.
- **Safe evolution** — a test suite around `step()` so we can change the core with confidence.

## Goals

1. `DragonPalmCore` lives in one place, importable from both the browser and Node.
2. CPU/ISA behaviour is **byte-for-byte identical** to today (the class is moved, not rewritten).
3. The "open `index.html` in a browser, drag a cart" experience is preserved **with no build
   step and no local server required** (see the constraint below — this is the crux).
4. A **headless Node test suite** that runs the shared core and can: (a) verify the assembler
   and CPU behave correctly, and (b) verify a *cart* behaves correctly — run it with scripted
   input for N frames and assert on the resulting screen state.

## Non-goals (explicitly out of scope for this change)

- No new opcodes, no ISA or timing changes, no renderer/audio changes.
- The test suite never runs in or depends on the browser — no headless-Chrome, no DOM.
- No CLI cart runner, disassembler, or debugger *yet* — this change only makes them possible.
  They are listed under Future Work.
- No package manager / bundler toolchain unless an option below forces it. The test suite
  prefers Node's built-in test runner (`node --test`) over an external framework.

## The crux: ES modules do not load over `file://`

This is the one real decision and the reason to plan before coding.

Today `index.html` is opened directly from disk (`file://...`), and the README tells users
to do exactly that. If we split the core out and load it with `import` / `<script type="module">`,
**the browser blocks it under `file://` for CORS reasons** — the page would only work when
served over `http://`. That silently breaks the project's defining feature.

So "extract to an ES module and `import` it" is *not* free. We must pick how the browser
gets the core:

### Option A — Classic shared script, dual-target (recommended)

Put the core in `tools/core.js` as a plain classic script that works in both worlds:

```js
class DragonPalmCore { /* ...moved verbatim... */ }
if (typeof module !== 'undefined') module.exports = { DragonPalmCore }; // Node
```

- Browser: `<script src="tools/core.js"></script>` before the main script — loads fine over
  `file://`, no module system, `DragonPalmCore` is just in scope.
- Node: `const { DragonPalmCore } = require('./tools/core.js')`.

**Pros:** keeps zero-build + `file://` promise intact; one source of truth; trivial Node
reuse. **Cons:** uses a global + a CommonJS tail (slightly old-fashioned, but it is the
honest fit for "no build, runs from disk").

### Option B — ES module + tiny build/inline step

Author the core as a real ES module; keep `index.html` self-contained by inlining the core
into it at build time (a small script concatenates core + page into a committed `index.html`,
or a `dist/`).

**Pros:** modern module syntax everywhere. **Cons:** introduces a build step and a
generated-file workflow for a project whose whole point is not having one. Higher risk of
"edited the wrong copy" drift.

### Option C — ES module + require a local server

Author as ES modules, drop `file://` support, tell users to run `npx serve` (or similar).

**Pros:** cleanest code. **Cons:** breaks the headline UX and the README's instructions.
Rejected unless we deliberately want to change the product's promise.

**Recommendation:** Option A. It is the only one that preserves the zero-build, open-from-disk
experience while giving Node a clean import, and it keeps a single un-generated source of truth.

## Proposed target layout (Option A)

```
tools/
  core.js        ← DragonPalmCore (CPU + p()/t()/frame()/step()), classic script + CommonJS export
  assembler.js   ← unchanged
index.html       ← keeps renderer, input, audio, loader; <script src="tools/core.js"> for the core
```

The split line is **CPU vs host**: `core.js` owns RAM, registers, `p()`, `t()`, `frame()`,
`step()`. `index.html` keeps everything that is browser-specific — the canvas/palette
rendering, keyboard/pointer input, `AudioContext` chime, drag-drop/file-picker loading, and
the `requestAnimationFrame` loop. The boot chime stays driven by `frame()`'s return value, as
today.

## Verification strategy (how we prove "behaviour identical")

The class is *moved verbatim*, so the logic risk is low; the real risk is wiring (load order,
the `file://` gotcha). We verify in three layers:

1. **Pre-extraction golden capture.** Before refactoring, add a throwaway Node script that
   pastes in *today's* core, runs each cart in `carts/*.dgc` for a fixed number of frames with
   a scripted input sequence, and records a hash/dump of VRAM (`$2000–$3FFF`) at set
   checkpoints. Save these goldens.
2. **Post-extraction comparison.** Run the same harness against the new `tools/core.js`. VRAM
   hashes must match the goldens exactly for all three carts.
3. **Manual browser smoke test.** Open `index.html` directly from disk (`file://`), confirm:
   boot animation + chime play, all three bundled carts run and respond to input, drag-drop
   and tap-to-pick still load carts, power toggle works. (The `verify`/`run` skills can drive this.)

Only after all three pass do we keep the change.

## Test suite design

Lives under `tests/`, run with `node --test` (zero dependencies). Three layers, cheapest first:

1. **Assembler tests** — assemble each `carts/*.asm` and assert the bytes equal the committed
   `.dgc`. This is a free regression net we can add *immediately*, before any extraction,
   since the assembler is already a standalone module and golden `.dgc` files already exist.
   Plus targeted cases: number bases, `EQU`, `DB`/`DW`, label arithmetic, the no-space-in-`[...]`
   rule, and expected failures (over-8192, unknown symbol).
2. **CPU / ISA tests** — drive the shared core directly: each opcode in isolation
   (`ADD_A`/`SUB_A` wrap at 255, `JNZ` taken vs not, `STA` ≥ `$4000` ignored, `LD_A [$4000]`
   reads input, `DRW` nibble packing and out-of-range rejection, PC wrap at 8191).
3. **Cart functionality tests** — the part you asked for. A small harness loads a `.dgc`,
   sets the input register, runs a fixed number of `frame()`/`step()` calls, and asserts on
   screen state via helpers like `pixelAt(x,y)` (decoding the packed VRAM nibble). Examples:
   *adder* draws at its start position; *tennis* moves the player paddle up when Up is held
   and the ball changes direction off a paddle; *magic-screen* plots the current colour under
   the cursor and `U`/`K` change it. These read as "given this input sequence, the screen
   shows this", which is exactly "does the game work" expressed as an assertion.

A `tests/harness.js` provides the shared helpers (load cart, pump N frames with an input
script, `pixelAt`, VRAM hash) so individual cart tests stay short and declarative.

This same harness produces the **golden VRAM hashes** used to gate the extraction
(Verification strategy above) — so the refactor safety net and the permanent cart-test suite
are one mechanism, not two.

## Step-by-step

1. Land this plan; agree on Option A (or pick another) and on test-layer priorities.
2. **Add assembler tests now** (layer 1) — needs no extraction; assert `carts/*.asm` →
   committed `.dgc`. Immediate value and an early `node --test` skeleton.
3. Write the `tests/harness.js` golden-capture path against *today's* inline core; record
   golden VRAM hashes for the 3 carts.
4. Move `DragonPalmCore` verbatim into `tools/core.js` with the dual-target export tail.
5. Replace the inline class in `index.html` with `<script src="tools/core.js"></script>`,
   placed before the host script; delete the now-duplicated class body.
6. Re-run the harness — VRAM hashes must match the goldens (proves the move was clean).
7. Manual `file://` browser smoke test (checklist above).
8. Add CPU/ISA tests (layer 2) and cart-functionality tests (layer 3) against `tools/core.js`.
9. Update `README.md`: add a "Testing" section (`node --test`); change run instructions only
   if the chosen option requires it (Option A: it does not).

## Risks & mitigations

| Risk | Mitigation |
| --- | --- |
| `file://` module breakage | Option A avoids modules entirely in the browser. |
| Script load-order bug (core not defined yet) | Place `core.js` `<script>` before the host script; smoke test catches it. |
| Two diverging copies of the core | Single source `tools/core.js`; no generated files in Option A. |
| Silent behaviour drift | Golden VRAM hashes for all carts gate the change. |

## Future work (unlocked by this, not part of it)

- `tools/run-cart.js` — headless cart runner (frames → PNG / ASCII dump) for CI & screenshots,
  reusing `tools/core.js` and the test harness.
- A CI workflow that runs `node --test` on every push (the suite is dependency-free, so this
  is cheap) — making "tests pass before pushing live" automatic, not manual.
- **Disassembler** (`.dgc` → `.asm`) reusing the opcode table.
- Step-tracer / debugger overlay for cart development.
- A reusable assertion vocabulary so cart authors (and the `dragon-palm-asm` skill) can write
  functionality tests for their own carts, not just the bundled three.
