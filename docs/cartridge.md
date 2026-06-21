# Dragon Palm Cartridge Format

Dragon Palm cartridges are raw 8192-byte binary dumps loaded directly into memory at `$0000`. Execution begins at `$0000`.

The SDK uses the `.dgc` extension for Dragon Game Cart files. No header, no checksum, no metadata, only program bytes.

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

Drag a `.dgc` file onto the Dragon Palm screen in the browser, or tap the screen on a touch device to open the system file picker. The emulator copies the binary bytes into RAM starting at `$0000` and sets `PC` to `$0000`.

## Cartridge Swapping

In the playgrounds of an alternate Britain, Dragon Palm carts were currency. Swapped on buses, borrowed over school dinners, pressed into sweaty palms with the gravity of a state secret. You might get three games in a week and never know where two of them came from. That was the point. The cart was the game and the game was the conversation that carried the country.

If you have built something worth swapping, submit it to the [dragon-carts](https://github.com/0xe25f/dragon-carts) repository. No particular standard is required beyond the game working, cartridge format above, and something worth playing. Small is fine. Strange is welcome. Unfinished-weird-but-interesting is a proud British tradition.
