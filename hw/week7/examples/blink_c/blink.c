#define GPIO_OUT (*(volatile unsigned int *)0x40000000)

static void delay(volatile unsigned int count) {
    while (count--) {
        __asm__ volatile ("nop");
    }
}

int main(void) {
    while (1) {
        GPIO_OUT = 0x01;
        delay(200000);
        GPIO_OUT = 0x00;
        delay(200000);
    }
    return 0;
}