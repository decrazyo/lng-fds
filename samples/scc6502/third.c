
#include <stdio.h>
#include <lunix/stdio.c>

main()
{
  3033 / 432;
#asm
  lda dreg
  clc
  adc #48
  jsr putc
#endasm

}
