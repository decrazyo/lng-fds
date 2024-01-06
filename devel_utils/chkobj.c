
#include <stdio.h>
#include <stdlib.h>

int read_byte(FILE *);
void do_frag(int);
void hex_out(int i);

int cnt;

int read_byte(FILE *fin)
{
  int i;

  i=fgetc(fin);
  if (i==EOF) {
    printf("unexpected end of file\n");
    exit(-1); }
  return i;
}

void do_frag(int i)
{
  switch (i & 0x0f) {
    case 1: { cnt++; printf(" (lo-byte only)\n"); break; }
    case 2: { cnt++; printf(" (hi-byte only)\n"); break; }
    case 3: { cnt+=2; printf(" (full word)\n"); break; }
    default: printf("(unknown pattern %i)\n",i & 0x0f); }
}

void hex_out(int i)
{
  static char digits[]="0123456789ABCDEF";

  printf("%c%c",digits[(i & 0xf0)>>4],digits[(i & 0x0f)]);
}

int main(int argc, char **argv)
{
  char *fname;
  int  i,j;
  FILE *fin;
  int  length;
  int  lo,hi;

  fname=argv[1];
  if (fname==NULL) {
  printf("Usage: %s objfile\n",argv[0]);
  exit(-1); }
  fin=fopen(fname,"rb");
  if (fin==NULL) {
    printf("i/o error\n");
    exit(-1); }

  printf("Magic: \"");
  printf("%c",read_byte(fin));
  printf("%c",read_byte(fin));
  printf("%c\"\n",read_byte(fin));

  printf("\nGlobals:\n");
  while ((i=read_byte(fin))!=0) {
    printf("\t%c",i);
    while ((i=read_byte(fin))!=0) printf("%c",i);
    lo=read_byte(fin);
    hi=read_byte(fin);
    printf(" = $");
    hex_out(hi);
    hex_out(lo);
    printf("\n"); }

  lo=read_byte(fin);
  hi=read_byte(fin);
  length=lo+256*hi;
  printf("\nLength of code is %i bytes \n",length);

  j=0;
  printf("\nExternals:\n");
  while ((i=read_byte(fin))!=0) {
    printf("\t[%i] %c",j,i);
    while ((i=read_byte(fin))!=0) printf("%c",i); 
    printf("\n");
    j++; }

  printf("\nCode-fragments:\n");
  cnt=0;
  while ((i=fgetc(fin))!=0) {
    if (i==EOF) break;
    printf("[%i]\t",cnt);
    if (i<0x80) {
      printf("%i static bytes",i);
      cnt+=i; j=0;
      while (i!=0) { 
        lo=read_byte(fin); 
        i--;
        if (j==0) { printf("\n\t\t"); j=16; }
        hex_out(lo);
        printf(" ");
        j--; }
      printf("\n"); }
    else if ((i & 0xf0)==0x80) {
      lo=read_byte(fin);
      hi=read_byte(fin);
      printf("relocate $");
      hex_out(hi);
      hex_out(lo);
      do_frag(i); }
    else if ((i & 0xf0)==0xc0) {
      lo=read_byte(fin);
      hi=read_byte(fin);
      printf("external[%i]", lo + (hi<<8));
      do_frag(i); }
    else if ((i & 0xf0)==0xd0) {
      lo=read_byte(fin);
      hi=read_byte(fin);
      printf("external[%i]", lo + (hi<<8));
      lo=read_byte(fin);
      hi=read_byte(fin);
      printf(" with offset $");
      hex_out(hi);
      hex_out(lo);
      do_frag(i); }
    else printf("unknown fragmentcode %i\n",i); }

  printf("\n");
  if (i!=0) printf("Missing $00 \"end of table\" marker!\n");
  else      printf("[%i]\tEND\n",cnt);
  if (fgetc(fin)!=EOF) printf("File is too long !\n");
  if (cnt!=length) printf("Code length is %i, but should be %i !\n",cnt,length);
  fclose(fin);
  return 0;
}  
