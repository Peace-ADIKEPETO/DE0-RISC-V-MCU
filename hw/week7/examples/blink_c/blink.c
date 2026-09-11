#include "riscv.h"

int main(void) {
    while (1) {
        led_on(7);          // LED[7] ON
        delay(5000000);     // ~100ms at 50MHz
        led_off(7);         // LED[7] OFF
        delay(5000000);
    }
    return 0;
}