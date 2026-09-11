#include "riscv.h"

int main(void) {
    uart_puts("DE0-RISCV MCU booted\r\n");
    uart_printf("System clock: %u Hz\r\n", 50000000);
    uart_printf("GPIO address: %x\r\n", 0x40000000);
    uart_puts("Type a character:\r\n");
    
    int count = 0;
    while (1) {
        if (uart_available()) {
            char c = uart_getc();
            uart_printf("[%d] Received: '%c' (0x%x)\r\n", count++, c, (uint32_t)c);
            led_toggle(7);
        }
    }
    return 0;
}