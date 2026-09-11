#ifndef UART_H
#define UART_H

#include <stdint.h>

#define UART_TX_DATA    (*(volatile uint32_t *)0x40001000)
#define UART_TX_STATUS  (*(volatile uint32_t *)0x40001004)
#define UART_RX_DATA    (*(volatile uint32_t *)0x40001008)

#define UART_TX_BUSY_BIT  0x1
#define UART_RX_VALID_BIT 0x100

void uart_putc(char c);
void uart_puts(const char *s);
int  uart_printf(const char *fmt, ...);
int  uart_available(void);
char uart_getc(void);

#endif