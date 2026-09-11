# start.S - RISC-V startup code for PicoRV32
# Sets stack pointer, clears BSS, calls main()

.section .text.start
.global _start

_start:
    # Set stack pointer
    la sp, _stack_top

    # Clear BSS
    la a0, _bss_start
    la a1, _bss_end
clear_bss:
    bgeu a0, a1, bss_done
    sw zero, 0(a0)
    addi a0, a0, 4
    j clear_bss
bss_done:

    # Call main
    call main

    # Hang if main returns
hang:
    j hang