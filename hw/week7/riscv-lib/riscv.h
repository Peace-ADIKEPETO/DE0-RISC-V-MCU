#ifndef RISCV_H
#define RISCV_H

#include <stdint.h>
#include "uart.h"

#define GPIO_OUT (*(volatile uint32_t *)0x40000000)
#define GPIO_IN  (*(volatile uint32_t *)0x40000004)

static inline void led_toggle(int bit) {
    GPIO_OUT ^= (1u << bit);
}

#endif