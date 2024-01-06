/*****************************************************************************

	    Confidential and Proprietary to Ivan A. Curtis

      Copyright (C) 1996, Ivan A. Curtis.  All rights reserved.

This precautionary copyright notice against inadvertent publication is
neither an acknowledgement of publication, nor a waiver of confidentiality.

*******************************************************************************
*******************************************************************************

Filename:	/u1/lang/scc/tests/extern.c

Description:

Update History:   (most recent first)
     I. Curtis   4-Jul-97 20:02 -- Created.

******************************************************************************/
#include <stdio.h>
#include <lunix/stdio.c>

int x;
char y;

put(j)
     char *j;
{
  putc(*j, stdout);
}

main()
{
  y = 'A';
  put(&y);
}
