#include "timer.h"

#define TIMER_PENDING_BIT 0x2

static volatile uint32_t ms_counter = 0;

void timer_init(uint32_t compare_value) {
    TIMER_COMPARE = compare_value;
    TIMER_CONTROL = TIMER_ENABLE;
}

void irq_handler(void) {
    uint32_t ctrl = TIMER_CONTROL;
    if (ctrl & TIMER_PENDING_BIT) {
        ms_counter++;
        TIMER_CONTROL = TIMER_ENABLE | TIMER_CLEAR_PEND;
    }
}

uint32_t millis(void) {
    return ms_counter;
}

void timer_delay_ms(uint32_t ms) {
    uint32_t start = millis();
    while ((millis() - start) < ms) {
        /* busy wait */
    }
}