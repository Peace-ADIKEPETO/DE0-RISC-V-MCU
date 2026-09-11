#!/usr/bin/env python3
# upload.py - Upload Intel HEX + interactive terminal

import serial
import sys
import time

def upload_and_interact(port, hex_file, baud=9600):
    ser = serial.Serial(port, baud, timeout=0.1)
    print(f"Connected to {port} at {baud} baud")
    time.sleep(2)

    with open(hex_file, 'r') as f:
        lines = f.readlines()

    print(f"Sending {len(lines)} lines...")
    for line in lines:
        line = line.strip()
        if line:
            ser.write((line + '\r\n').encode())
            time.sleep(0.05)

    print("Waiting for ACK...")
    time.sleep(1)
    response = b''
    while ser.in_waiting:
        response += ser.read(ser.in_waiting)
    print(f"Response: {response}")

    print("\n" + "=" * 50)
    print("Type characters. Ctrl+C to quit.")
    print("=" * 50 + "\n")

    try:
        import msvcrt
        while True:
            # Read FPGA output
            if ser.in_waiting:
                data = ser.read(ser.in_waiting)
                print(data.decode('ascii', errors='replace'), end='', flush=True)


            ser.write("P".encode())

            time.sleep(0.1)
    except KeyboardInterrupt:
        pass

    ser.close()
    print("\nDisconnected.")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python upload.py <COM_PORT> <hex_file>")
        sys.exit(1)
    upload_and_interact(sys.argv[1], sys.argv[2])