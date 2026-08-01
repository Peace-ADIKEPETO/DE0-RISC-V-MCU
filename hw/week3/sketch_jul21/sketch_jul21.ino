#include <SoftwareSerial.h>

SoftwareSerial fpgaSerial(8, 13); // RX = pin 8, TX = pin 13

void setup() {
  Serial.begin(115200);
  fpgaSerial.begin(115200);

  pinMode(8, INPUT);
  pinMode(13, OUTPUT);
}

void loop() {
  if (Serial.available()) {
    fpgaSerial.write(Serial.read());  // PC → FPGA via pin 9
  }
  if (fpgaSerial.available()) {
    Serial.write(fpgaSerial.read());  // FPGA → PC via pin 8
  }
}