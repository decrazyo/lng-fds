/*****************************************************************************

	    Confidential and Proprietary to Ivan A. Curtis

      Copyright (C) 1996, Ivan A. Curtis.  All rights reserved.

This precautionary copyright notice against inadvertent publication is
neither an acknowledgement of publication, nor a waiver of confidentiality.

*******************************************************************************
*******************************************************************************

Filename:	/u1/lang/scc/tests/case.c

Description:	test case statement

Update History:   (most recent first)
     I. Curtis  30-Jun-97 21:30 -- Created.

******************************************************************************/
#include <stdio.h>
#include <lunix/stdio.c>
main()
{
  int c;
    fputs("Press a key (a,b,c,q to quit)\n\r", stdout);
  do {
    c = getc(stdin);
    switch (c) {
    case 'a':
    case 'A':
      fputs("Got a\n\r", stdout);
      break;
    case 'b':
    case 'B':
    case 'c':
    case 'C':
      fputs("Got b or c\n\r", stdout);
      break;
    default:
      fputs("Got something else\n\r", stdout);
	case EOF:
      break;
    }
  }
  while ((c != 'Q') && (c != 'q'));
}
