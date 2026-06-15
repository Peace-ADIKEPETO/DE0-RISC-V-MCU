# DE0-RISC-V MCU

Build a complete RISC-V microcontroller on a Terasic DE0-Nano FPGA in 12 weeks.

## Goal
By Week 12, write C code, compile with riscv32-gcc, upload via UART, and run on custom RISC-V hardware.

## Hardware
- Terasic DE0-Nano (Cyclone IV EP4CE22F17C6N)
- 50MHz clock, 8 LEDs, 4 DIP switches, 2 buttons
- External: USB-UART adapter, 0.96" I2C OLED (optional)

## Stack
- **CPU:** PicoRV32 (RISC-V RV32IM)
- **Language:** VHDL (hardware), C (firmware), Python (upload)
- **Tools:** Quartus Prime Lite 20.1, ModelSim, riscv32-unknown-elf-gcc

## Progress
- [ ] Week 1: LED blink 1Hz
- [ ] Week 2: GPIO module
- [ ] Week 3-4: UART TX/RX
- [ ] Week 5-6: PicoRV32 + UART bootloader
- [ ] Week 7-8: C toolchain + blink.c
- [ ] Week 9-10: Timer, Interrupts, SPI OLED
- [ ] Week 11-12: Integration + Dhrystone

## Week 1: LED Blink (In Progress)
- [ ] led_blink.vhd written
- [ ] ModelSim simulation passed
- [ ] Hardware test: LED0 blinking at 1Hz