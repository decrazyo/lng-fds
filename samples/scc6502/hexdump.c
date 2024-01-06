/*****************************************************************************

	    Confidential and Proprietary to Ivan A. Curtis

      Copyright (C) 1996, Ivan A. Curtis.  All rights reserved.

This precautionary copyright notice against inadvertent publication is
neither an acknowledgement of publication, nor a waiver of confidentiality.

*******************************************************************************
*******************************************************************************

Filename:	/u1/lang/scc/tests/hexdump.c

Description:	poor mans hexdump utility
	formats the input stream into a hex dump

Update History:   (most recent first)
     I. Curtis  27-Jun-97 21:22 -- Created.

******************************************************************************/
#include <stdio.h>
#include <lunix/stdio.c>

/*
 * Output the number n as a hex digit
 */
outhex(n)
     int n;
{
  n &= 0xf;
  if (n > 9) {
    n += 'a' - 10;
  } else {
    n += '0';
  }
  putc(n, stdout);
}

#define PerLine 8
main()
{
  int c, j, a;
  c = getc(stdin);
  j = 0;
  a = 0;
  while (c != EOF) {
    if (j == PerLine) {
      j = 0;
      a += PerLine;
      putc('\n', stdout);
      putc('\r', stdout);
    }
    if (j == 0) {
      outhex(a >> 12);
      outhex(a >> 8);
      outhex(a >> 4);
      outhex(a);
    }
    putc(' ', stdout);
    outhex(c >> 4);
    outhex(c);
    j ++;
    c = getc(stdin);
  }
  putc('\n', stdout);
  putc('\r', stdout);
}
