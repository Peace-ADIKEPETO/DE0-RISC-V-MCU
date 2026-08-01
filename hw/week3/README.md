# Week 3-4: Full-Duplex UART TX/RX — 115200 baud 8N1

## Goal
Build a complete bidirectional UART peripheral. Week 3: FPGA transmits "Hello World!" to PC. 
Week 4: FPGA echoes back any character typed in the terminal.

## Hardware Setup
- **FPGA:** DE0-Nano (Cyclone IV EP4CE22F17C6N)
- **Bridge:** Arduino Uno with SoftwareSerial
- **Wiring:**
| DE0-Nano GPIO_0 | Arduino Uno |
|-----------------|-------------|
| Pin 1, GPIO_0[0] (PIN_D3) — FPGA TX | Pin 8 (SoftwareSerial RX) |
| Pin 2, GPIO_0[1] (PIN_C3) — FPGA RX | Pin 13 (SoftwareSerial TX) |
| Pin 12 — GND | GND |
- **Arduino Sketch:** `sketch_jul21.ino` — receives on pin 8 and transmit on pin 13 via SoftwareSerial, forwards to PC via hardware Serial

## Baud Rate
- 115200 baud, 8 data bits, 1 stop bit, no parity (8N1)
- BIT_PERIOD = 50,000,000 / 115,200 = 434 clock cycles

## Files
- `uart.vhd` — FULL UART with single-register shifter for transmitter process
- `hello_uart_top.vhd` — Top-level sequencer sending "Hello World!\r\n"
- `echo_top.vhd` — Top-level for FULL UART test
- `uart_tx_tb.vhd` — ModelSim testbench
- `uart_tb.vhd` — ModelSim testbench
- `week3.qpf/qsf` — Quartus project and pin assignments
- `sketch_jul21.ino` — Arduino SoftwareSerial bridge sketch

## Architecture: Single-Register Shifter
The transmitter loads the full 10-bit packet [STOP, D7..D0, START] into a shift register on `tx_start`. The LSB drives `tx` combinationally for instant start bit response. The register shifts right every bit period until all 10 bits are sent.

**Key design decisions:**
- `tx <= tx_reg(0)` — combinational assignment, no start bit delay
- `tx_busy` asserts immediately on `tx_start`, eliminating race conditions
- Simplified FSM: IDLE → LOAD → SHIFT (10 bits) → IDLE

## Top-Level Sequencer
Three-state FSM: `INTER_MSG_DELAY → SEND_CHAR → WAIT_UART_READY`
- Sends all 14 characters ("Hello World!\r\n") sequentially
- Waits for `tx_busy = '0'` before sending next character
- 1-second delay between complete messages

## Result
![cht1](cht1.png)
![cht2](cht2.png)

## Result echo UART<->FPGA
![cht3](cht3.png)

## Simulation for UART TX test
![sim1](sim1.png)
![sim2](sim2.png)

## Simulation for full UART
![sim3](sim3.png)
![sim4](sim4.png)

## Hardware Test
- ✅ Arduino SoftwareSerial bridge working (pin 8)
- ✅ "Hello World!" appears in Serial Monitor at 115200 baud
- ✅ Message repeats every ~1 second
- ✅ Debug LEDs confirm FSM state transitions
- ✅ Full-duplex: TX and RX operate independentl

## Bugs Fixed
1. **Late start bit:** Original FSM delayed start bit by one baud period. Fixed with combinational `tx <= tx_reg(0)`.
2. **Missing last character:** Original sequencer cut off `\n`. Fixed by correcting `msg_idx` boundary check.
3. **Race condition:** Multi-state handshake (`WAIT_BUSY` → `GAP`) could miss `tx_busy` edge. Consolidated into single `WAIT_UART_READY` state.
4. **Baud rate mismatch:** SoftwareSerial unreliable at 115200 initially. Switched to hardware Serial (pin 0) with RESET-GND bridge, then validated SoftwareSerial on pin 8 also works.

## Key Learnings
- UART frame format: START(0) + 8 data bits (LSB first) + STOP(1)
- Clock enable vs derived clock for baud generation
- Combinational output assignment for instant timing response
- SoftwareSerial limitations on Arduino Uno
- Multi-state handshake simplification for reliable data transfer
- Mid-bit sampling gives maximum noise immunity