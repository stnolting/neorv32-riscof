OUTPUT_ARCH( "riscv" )
ENTRY(rvtest_entry_point)

SECTIONS
{
  . = 0x00000000;
  .text :
  {
    *(.text.init)
/*  . = ALIGN(0x1000);  */
    *(.tohost)
/*  . = ALIGN(0x1000);  */
    *(.text)
/*  . = ALIGN(0x1000);  */
    *(.data)
    *(.data.string)
    *(.bss)
    _end = .;
  }
}
