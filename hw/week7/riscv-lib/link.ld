ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS
{
    .text.start 0x00000000 : {
        *(.text.start)
    } > RAM

    .text.irq 0x00000010 : {
        *(.text.irq)
    } > RAM

    .text : {
        *(.text*)
    } > RAM

    .rodata : { *(.rodata*) } > RAM
    .data   : { *(.data*)   } > RAM
    .bss    : {
        _bss_start = .;
        *(.bss*)
        *(COMMON)
        _bss_end = .;
    } > RAM

    . = ALIGN(4);
    _stack_top = ORIGIN(RAM) + LENGTH(RAM) - 4;

    /DISCARD/ : { *(.comment) *(.note*) }
}