/*
 * Simple test code for scc
 *
 *    I. Curtis  16-Jun-97 21:08 -- created
 */
#include <stdio.h>
#include <lunix/stdio.c>

#define MaxLen 80
main()
{
  char s[MaxLen];
  fputs("What is your name ? ", stdout);
  fgets(s, MaxLen, stdin);
  fputs("Hello ", stdout);
  fputs(s, stdout);
}
