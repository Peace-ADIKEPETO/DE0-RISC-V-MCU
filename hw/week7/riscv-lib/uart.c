#include "uart.h"
#include <stdarg.h>

void uart_putc(char c) {
    while (UART_TX_STATUS & UART_TX_BUSY_BIT) {
        /* wait for previous byte to finish */
    }
    UART_TX_DATA = (uint32_t)(unsigned char)c;
}

void uart_puts(const char *s) {
    while (*s) {
        uart_putc(*s++);
    }
}

int uart_available(void) {
    return (UART_RX_DATA & UART_RX_VALID_BIT) ? 1 : 0;
}

char uart_getc(void) {
    while (!(UART_RX_DATA & UART_RX_VALID_BIT)) {
        /* block until a byte arrives */
    }
    return (char)(UART_RX_DATA & 0xFF);
}

static void utoa_base(unsigned int value, unsigned int base, int uppercase) {
    char buf[32];
    int i = 0;
    const char *digits = uppercase ? "0123456789ABCDEF" : "0123456789abcdef";

    if (value == 0) {
        uart_putc('0');
        return;
    }

    while (value > 0) {
        buf[i++] = digits[value % base];
        value /= base;
    }

    while (i > 0) {
        uart_putc(buf[--i]);
    }
}

static void itoa_signed(int value) {
    if (value < 0) {
        uart_putc('-');
        utoa_base((unsigned int)(-value), 10, 0);
    } else {
        utoa_base((unsigned int)value, 10, 0);
    }
}

int uart_printf(const char *fmt, ...) {
    va_list args;
    va_start(args, fmt);

    while (*fmt) {
        if (*fmt != '%') {
            uart_putc(*fmt++);
            continue;
        }

        fmt++;  /* skip '%' */

        switch (*fmt) {
            case 'd': itoa_signed(va_arg(args, int)); break;
            case 'u': utoa_base(va_arg(args, unsigned int), 10, 0); break;
            case 'x': utoa_base(va_arg(args, unsigned int), 16, 0); break;
            case 'X': utoa_base(va_arg(args, unsigned int), 16, 1); break;
            case 'c': uart_putc((char)va_arg(args, int)); break;
            case 's': uart_puts(va_arg(args, const char *)); break;
            case '%': uart_putc('%'); break;
            default:
                uart_putc('%');
                uart_putc(*fmt);
                break;
        }
        fmt++;
    }

    va_end(args);
    return 0;
}