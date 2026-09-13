#include "riscv.h"
#include "timer.h"

int main(void) {
    uart_puts("Timer test\r\n");
    
    timer_init(50000);  // 1ms
    irq_enable();
    
    uart_puts("Timer initialized (1ms)\r\n");
    
    uint32_t last_print = 0;
    while (1) {
        uint32_t now = millis();
        if (now - last_print >= 1000) {
            uart_printf("Uptime: %u ms\r\n", now);
            led_toggle(7);
            last_print = now;
        }
    }
    return 0;
}