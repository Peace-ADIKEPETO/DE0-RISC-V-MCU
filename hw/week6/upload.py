#!/usr/bin/env python3
# upload.py - Send Intel HEX file to FPGA bootloader over UART with debug

import serial
import sys
import time


def upload_hex(port, hex_file, baud=9600):
    """Send .hex file to FPGA bootloader."""

    ser = serial.Serial(port, baud, timeout=5)

    print(f"Connected to {port} at {baud} baud")

    with open(hex_file, 'r') as f:
        lines = f.readlines()

    time.sleep(2)  # Wait for Arduino reset

    print(f"Sending {len(lines)} lines from {hex_file}...\n")

    for line in lines:
        line = line.strip()
        if line:
            ser.write((line + '\r\n').encode())
            time.sleep(0.3)  # Longer delay for debug

    print("\nWaiting for boot ACK...")
    print("(Listening for any response...)\n")

    time.sleep(1)
    # Read everything for 5 seconds
    start = time.time()
    response = b''
    while time.time() - start < 5:
        if ser.in_waiting:
            chunk = ser.read(ser.in_waiting)
            response += chunk
            print(f"<<< {chunk}")
        time.sleep(0.1)

    if b'O' in response:
        print("\n✓ Boot successful! CPU is running.")
    elif response:
        print(f"\nGot response but no 'O': {response}")
    else:
        print("\n✗ No response from FPGA.")

    ser.close()


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python upload.py <COM_PORT> <hex_file>")
        sys.exit(1)

    upload_hex(sys.argv[1], sys.argv[2])