#ifndef RISCV_H
#define RISCV_H

#include <stdint.h>
#include "uart.h"

#define GPIO_OUT (*(volatile uint32_t *)0x40000000)
#define GPIO_IN  (*(volatile uint32_t *)0x40000004)

static inline void led_toggle(int bit) {
    GPIO_OUT ^= (1u << bit);
}

static inline void irq_enable(void) {
    register uint32_t a0 __asm__("a0") = 0;
    __asm__ volatile (".insn r 0x0B, 0x6, 0x03, a0, a0, x0" : "+r"(a0));
}

static inline void irq_disable(void) {
    register uint32_t a0 __asm__("a0") = 0xFFFFFFFF;
    __asm__ volatile (".insn r 0x0B, 0x6, 0x03, a0, a0, x0" : "+r"(a0));
}

#endif