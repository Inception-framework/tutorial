OUTPUT_FORMAT("elf32-littlearm")

OUTPUT_ARCH(arm)

ENTRY(Reset_Handler)

MEMORY
{
  VECTOR (rx) : ORIGIN = 0x10000000, LENGTH = 0x400   /* 256k */
  FLASH (rx) : ORIGIN = 0x10000400, LENGTH = 0xFFFBFF /*0xFFFFFF  256k */
  RAM (rwx)  : ORIGIN = 0x20000000, LENGTH = 0xFFFF   /*  32k */
}

STACK_SIZE = 8200;

SECTIONS
{
  .interrupt_vector :
  {
    *(.cs3.interrupt_vector);
  } > VECTOR

 .code :
 {
   CREATE_OBJECT_SYMBOLS
   *(.text .text.*);
 } > FLASH

 .data :
 {
   *(.rodata .rodata.*);
   *(.data .data.*);
   *(.bss .bss.*);
 } > RAM

 .bss : {
    *(.bss .bss.*)
    *(COMMON)
    . = ALIGN(4);
 } > FLASH

 .stack : {
  _stack_start_ = .;
  KEEP(*(STACK))
  . += STACK_SIZE;
  . = ALIGN (4);
  _stack_end_ = .;
 } > RAM

 STACK = _stack_start_;
}
