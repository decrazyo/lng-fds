
#include <stdio.h>
#include <lunix/stdio.c>

Putc(c)
     int c;
{
#asm
  ldy #2
  jsr bfetch_s
  jsr putc
#endasm
}

Puts(s)
     char *s;
{
  while (*s) {
    Putc(*s);
    s ++;
  }
}

/*
 * Put an integer as decimal to
 * stdout
 */
Puti(i)
     int i;
{
  int d, q, l;
  d = 10000;
  l = 1;
  while (d > 0) {
    q = i / d;
    i = i - q * d;
    if (!l || q != 0) {
      Putc('0' + q);
      l = 0;
    }
    d /= 10;
  }
}

main()
{
  int a, b, c;
  a = 205;
  b = 107;
  c = a + b;
  Puts("hello, world\r");
  Puts("this is sccm6502\r");
  Puti(a);
  Putc(' ');
  Puti(b);
  Putc(' ');
  Puti(c);
  Putc('\r');
}
