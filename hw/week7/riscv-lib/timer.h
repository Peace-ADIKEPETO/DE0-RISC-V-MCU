#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>

#define TIMER_CONTROL   (*(volatile uint32_t *)0x40002000)
#define TIMER_COMPARE   (*(volatile uint32_t *)0x40002004)
#define TIMER_COUNT     (*(volatile uint32_t *)0x40002008)

#define TIMER_ENABLE     0x1
#define TIMER_CLEAR_PEND 0x2

void timer_init(uint32_t compare_value);
uint32_t millis(void);
void timer_delay_ms(uint32_t ms);

#endif