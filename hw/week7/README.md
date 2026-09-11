# Week 7: RISC-V C Toolchain

## Goal
Replace hand-assembled HEX with a real C toolchain. Write C, compile with `riscv-none-elf-gcc`, produce Intel HEX, upload via bootloader.

## Toolchain
- **GCC:** xPack riscv-none-elf-gcc 15.2.0
- **Make:** xPack Windows Build Tools 4.4.1
- **Flags:** `-march=rv32i -mabi=ilp32 -Os -ffreestanding -nostdlib -nostartfiles`
- **Output:** ELF → Intel HEX via `objcopy -O ihex`

## Project Structure
hw/week7/
├── riscv-lib/
│ ├── riscv.h # GPIO macros, delay helper
│ ├── start.S # Stack setup, BSS clear, call main
│ ├── link.ld # Memory layout (16KB RAM at 0x0)
│ └── Makefile.common # Shared build rules
└── examples/
└── blink_c/
├── blink.c # LED[7] blink program
└── Makefile


## Memory Layout
| Region | Address | Size |
|--------|---------|------|
| RAM (text, data, bss, stack) | 0x00000000 | 16KB |
| Stack top | 0x00003FFC | — |
| GPIO out | 0x40000000 | 4 bytes |
| GPIO in | 0x40000004 | 4 bytes |

## Linker Script Notes
- `.text.start` placed at address 0 (reset vector)
- `_stack_top = 0x3FFC` — matches PicoRV32 `STACKADDR` generic
- GPIO not in `MEMORY` — accessed via volatile pointer

## Startup Code (`start.S`)
1. `la sp, _stack_top` — establish stack (PicoRV32 doesn't do this on reset)
2. Clear BSS between `_bss_start` and `_bss_end`
3. `call main`
4. Hang if main returns

## Build Commands
```bash
cd hw/week7/examples/blink_c
make              # compile and link
make disasm       # show disassembly
make clean        # remove build artifacts
```

## Build Output
   text    data     bss     dec     hex filename
    124       0       0     124      7c blink.elf

## Built blink.hex
Upload: python ../../bootloader/upload.py COMx blink.hex

## Hardware Test
☑ riscv-none-elf-gcc installed and on PATH
☑ make builds blink.hex
☑ Disassembly verified clean RV32I
☑ Python upload script accepts GCC-generated HEX
☑ LED[7] blinks at ~1.25 Hz on DE0-Nano