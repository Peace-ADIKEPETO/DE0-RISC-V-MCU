#include <SoftwareSerial.h>

SoftwareSerial fpgaSerial(8, 9); // RX=pin8, TX=pin9

void setup() {
  Serial.begin(9600);      // USB to PC
  fpgaSerial.begin(9600);  // FPGA
}

void loop() {
  if (Serial.available()) {
    fpgaSerial.write(Serial.read());  // PC → FPGA
  }
  if (fpgaSerial.available()) {
    Serial.write(fpgaSerial.read());  // FPGA → PC
  }
}