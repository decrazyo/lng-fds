
#include <stdio.h>
#include <lunix/stdio.c>

/*
 * Simple test code for scc
 *
 *    I. Curtis  16-Jun-97 21:08 -- created
 */
puts(s)
     char *s;
{
  while (*s) {
    *s;
#asm
  lda dreg
  jsr putc
#endasm
    s++;
  }
}

main()
{
  puts("hello, world\r");

}
