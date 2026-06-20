# Dragon Palm Cartridge Format

Dragon Palm cartridges are raw 8192-byte binary dumps loaded directly into memory at `$0000`. Execution begins at `$0000`.

The SDK uses the `.dgc` extension for Dragon Game Cart files. If older notes refer to `.dpc`, the binary format is the same: no header, no checksum, no metadata, only program bytes.

## Layout

| Offset | Size | Use |
| --- | ---: | --- |
| `$0000-$1FFF` | 8192 bytes | Program bytes and any writable program-space data. |

Files shorter than 8192 bytes must be padded with zero bytes. Files longer than 8192 bytes are invalid for a standard cartridge.

## Building

Use the SDK assembler:

```sh
node tools/assembler.js carts/magic-screen.asm carts/magic-screen.dgc
```

If no output path is supplied, the assembler writes a `.dgc` file beside the source file.

## Loading

Drag a `.dgc` file onto the Dragon Palm screen in the browser. The emulator copies the binary bytes into RAM starting at `$0000` and sets `PC` to `$0000`.

