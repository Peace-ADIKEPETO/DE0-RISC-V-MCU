.section .text.start
.global _start

_start:
    j reset_handler   # single 4-byte jump: keeps this section tiny so the
                       # IRQ handler can land exactly at 0x10 below

.section .text.irq
.global _irq_handler

_irq_handler:
    # Full caller-saved register set must be preserved -- an interrupt can
    # land at ANY point in the foreground code, not just a call boundary,
    # so every register a C function is free to clobber must be saved.
    addi sp, sp, -64
    sw ra,   0(sp)
    sw t0,   4(sp)
    sw t1,   8(sp)
    sw t2,  12(sp)
    sw t3,  16(sp)
    sw t4,  20(sp)
    sw t5,  24(sp)
    sw t6,  28(sp)
    sw a0,  32(sp)
    sw a1,  36(sp)
    sw a2,  40(sp)
    sw a3,  44(sp)
    sw a4,  48(sp)
    sw a5,  52(sp)
    sw a6,  56(sp)
    sw a7,  60(sp)

    call irq_handler

    lw ra,   0(sp)
    lw t0,   4(sp)
    lw t1,   8(sp)
    lw t2,  12(sp)
    lw t3,  16(sp)
    lw t4,  20(sp)
    lw t5,  24(sp)
    lw t6,  28(sp)
    lw a0,  32(sp)
    lw a1,  36(sp)
    lw a2,  40(sp)
    lw a3,  44(sp)
    lw a4,  48(sp)
    lw a5,  52(sp)
    lw a6,  56(sp)
    lw a7,  60(sp)
    addi sp, sp, 64

    .insn r 0x0B, 0x0, 0x02, x0, x0, x0   # retirq

.section .text
reset_handler:
    la sp, _stack_top

    la a0, _bss_start
    la a1, _bss_end
clear_bss:
    bgeu a0, a1, bss_done
    sw zero, 0(a0)
    addi a0, a0, 4
    j clear_bss
bss_done:

    call main

hang:
    j hang