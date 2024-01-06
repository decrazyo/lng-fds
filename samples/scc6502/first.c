/*
 * Simple test code for scc
 *
 *    I. Curtis  16-Jun-97 21:08 -- created
 */

#include <stdio.h>
#include <lunix/stdio.c>

main()
{
  char b;

  b = 'A';
#asm
  ldy #0
  jsr bfetch_s
  jsr putc
#endasm

}
