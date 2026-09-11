#ifndef RISCV_H
#define RISCV_H

#include <stdint.h>

// =============================================
// Memory-mapped I/O
// =============================================
#define GPIO_OUT  (*(volatile uint32_t *)0x40000000)
#define GPIO_IN   (*(volatile uint32_t *)0x40000004)

// =============================================
// Delay loop (no rdcycle — ENABLE_COUNTERS=0)
// =============================================
static inline void delay(volatile uint32_t cycles) {
    while (cycles--) {
        __asm__ volatile ("nop");
    }
}

// =============================================
// LED helpers (active high on DE0-Nano)
// =============================================
static inline void led_set(uint32_t mask) {
    GPIO_OUT = mask & 0xFF;
}

static inline void led_on(uint8_t led) {
    GPIO_OUT |= (1 << led);
}

static inline void led_off(uint8_t led) {
    GPIO_OUT &= ~(1 << led);
}

static inline void led_toggle(uint8_t led) {
    GPIO_OUT ^= (1 << led);
}

static inline uint32_t switch_read(void) {
    return GPIO_IN & 0xF;
}

#endif // RISCV_H