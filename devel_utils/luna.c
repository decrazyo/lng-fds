/* LUnix-assembler Version 1.31

   Written by Daniel Dallmann (aka Poldi) on a weekend in June 1996 :-)
   This piece of software is freeware ! So DO NOT sell it !!
   You may copy and redistribute this file for free, but only with this header
   unchanged in it. (Or you risc eternity in hell)

   If you've noticed a bug or created an additional feature, let me know.
   My (internet) email-address is dallmann@heilbronn.netsurf.de

luna-extension-history:

 Sep 30 2001 *poldi* fixed: open output files in binary mode

 Nov 15 2000 *mouse* added: .aasc ("apple ascii") for raw printing of chars
		     and getaascii() function to do so

 Feb 18 2000 *poldi* added: \n \r \t \0 in .text "..." string
                     changed: #"<char>" now plain ascii (no petscii conversion)

 Sep 21 1999 *poldi* added: ^ (eor) operator

 Jul  6 1999 *poldi* added: "-W" switch for warnings (unused labels)

 Jun  9 1999 *poldi* code cleaning

 Jun  8 1999 *Stefan Haubenthal* AMIGA related patches

 May 25 1999 *poldi* fixed: bug with .word and externals with offset

 Nov  5 1998 *poldi* fixed: bug in .text processing removed (endless loop)

 Nov  4 1998 *poldi* added: -R switch (to generate code without the
                            normal 2 byte starting address header)

 Aug  7 1998 *poldi* added: -dname[=macro] options are passed through to
                            lupo.
                     added: .digit value[,value,...]
                            value in range 0..15 converted into hexadecimal
                            digit.

 Nov 23 1997 *poldi* added: support of 32bit arrithmetic
                     added: .longword  (dumps a longword with MSB first)

 Nov 16 1997 *paul g-s* Added: > operator (like 65536>8 = 256) to help with 
                         using lcc.
                      Added: .. to mean allocate 4 bytes of zp , like . does
                       two.  (again, to help with using lcc).

            *poldi*   added: < operator
                      fixed: byte/word opcodes, when using
                             unresolved (external) labels
                      fixed: delete temporary file in every case

 Jul 4 1997 *icurtis* removed: Removed warning generated for unused labels,
                               when in quiet mode.
                      added: \t notation for tab character

 Jun 27 1997 *poldi* added: undefined global will be considered global
                     (so the global directive can be used like a kind of
                     function prototype without error)

 Jun 21 1997 *poldi* fixed: -1 assigned to unsigned char ?
                     fixed: remove tmpfile, if lupo returnes with error
                     added: automatic lld post-proccessing (-L switch)

 Jun 15 1997 *poldi* fixed: ZP-externals (not supported) will generate error
                            message
                     fixed: < > operators in object_mode
                     fixed: plainbuf-error in object_mode
                     fixed: buf-error at end of file in object_mode
                     (luna history rearranged)

 Jun 8 1997 *poldi* fixed: no warning about unused external labels in
                           objectmode.

             added some speed-ups.

 May 18 1997 *paul g-s* Added (compile time) option to luna to give error
                     messages which Emacs can understand.
		     use #define EMACS_ERRORS when compiling luna to enable

		     Added preprocessing by lupo by default.
		     Use -p to disable.
		     This required adding a .line directive to let luna know 
		     where the line really came from

		     Made the code so it will compile with no warnings -Wall

		     Added signal labels for drivers (pload & prockilled)

		     Added .text directive (preliminary for now)
		     (does not handle '\' escapes, only quoted text and
		     expressions, eg:
		     .text "foobar",$0d,"more text",$00

		     Bugfix: nextsep now handles strings correctly

 May 14 1997 *poldi* added: -j switch to suppress automatic conversion
                            of conditional relative branches into conditional
                            absolute jumps. (speeds up)
                     changed: reduced number of warnings about relative jumps,
                            that are out of range.

 Mar  6 1997 *poldi* fixed: "conditional jump to external" error message
                             without being in object mode.

 Jan 26 1997 *poldi* bugfixes: side-effects because of too little msgbuf size

 Jan  1 1997 *poldi* bugfixes: upper/lowercase in CMD names
                               character constant " "
                               strings beginning with spaces

 Dec 17 1996 *poldi* fixed bug with .byte #< or #> (take hi/lo-byte) in 
                     object-mode, when applied to a PC-relative or
                     external address.

 Dec 15 1996 *poldi* added support of LUnix-objects
                     fixed bug with absolute addresses in object mode

 Nov 1  1996 *poldi* added "~" - invert operator
                     added &   - AND in expressions
                     added |   - OR  in expressions
                     [...] can be used the same way as (...) in expressions

 Oct 28 1996 *poldi* fixed bug with ".buf"s at start of code.

 Sep 4  1996 *poldi* rewritten parsing of expressions.
                     support of (linkable) object code.

 Aug 24 1996 *poldi* rewritten commandline parsing:
                       -q = quiet-mode commandline-switch
                       -o output-file
                       -l label-file

 Aug 22 1996 *poldi* unknown labels are now reported only once.
                     removed ugly bug with addressingmode 12 (A).

 Jul 28 1996 *poldi* brackets in expressions. eg. "#(2+3)-(9-(6-2))" is 
                     possible now.

                     new assembler directive:
                     .global label[,label,...] - mark label(s) global, 
                       after compilation a list of all globals and their value
                       is saved in outfilename+".labels".

                     - Hex values now lower or uppercase.

 Jul  7 1996 *poldi* new assembler directives:
                     .newpage - align to start of (next) page
                     .buf n   - insert n bytes

                     In expressions "*" dissolves to value of PC
                     
                     LUnix-mode:
                     .code      - enter code-area (default after .header)
                     .data      - enter data-area (inserts $0c <code-address>)
                     .endofcode - enter data-area for rest of file
                                   (relocation ends here, $02 inserted)

                     Feature: - ".buf"s at the very end will not be included
                                into the output file (that saves discspace)
                              - header directive allocates 2 bytes at once if
                                ZP-label has a "."-prefix.

                     removed bugs: comments after header-directive now ok.

 Jun 28 1996 *poldi* inproved error detection (recursive label definitions)
                     writing of label-list included (experimental)

 Jun 26 1996 *poldi* added ".header" directive
 ...

*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

/* #define debug */

/* Nice emacs compatible error messages */
#define EMACS_ERRORS


/*#define LINE_LEN  100*/   /* max line-length */
#define LINE_LEN  0x100   /* max line-length */

#define LABEL_MAX 1500  /* max number of used labels */
#define AVG_LABEL_LEN 8 /* just an average for calculating max labelspace */
#define LABEL_LEN 30    /* max length of labels */

#define NO_LABEL  (-1)  /* value not matched by [0..LABEL_MAX] */
#define DUP_LABEL (-2)  /*                 ''                  */

#ifdef _AMIGA
const char *VERsion="$VER: luna 1.31 "__AMIGADATE__" $";
#endif

/* Fnuction prototypes */

void Howto(void);
void error(char*);
void warning(char*);
int Readline(void);
int nextchar(int);
int is_sep(int);
int nextsep(int);
int strwant(int*, char*);
void cleanup_plain_buf(void);
void setlabel(char*, unsigned long, int);
int search_label(char*);
int insert_label(char*, int*);
int getascii(int,int*,int);
int getaascii(int,int*);
void setglobal(char*);
int getlabel(char*);
int getval(int, unsigned long*, int*, int*);
int getterm(int, unsigned long*, int*, int*);
int getasspar(int, int*, int*, int*, int*);
int getexpr(int, unsigned long*, int*, int*);
void raw_put(int);
void putbyte(int, int, int);
void putword(int, int, int);
void writebef(int, int, int, int, int);
void setsigjmp(char*, int);
char *my_tmpnam(char*);
int addopt(char*, int, char*);

/* global variables */

static FILE *infile;
static FILE *binfile;
static int  pass;
static int  final_pass;
static int  unknown_flag;
static int  alter_flag;
static int  org_lock;
static int  lunix_mode;
static int  header[64];
static int  _line;
static char line[LINE_LEN+1];
static char msgbuf[LABEL_LEN+60];
static int  pc;
static int  pc_end;
static int  pc_begin;
static int  code_length;
static int  fmark,rmark,fmarks,rmarks;
static char label_tab[LABEL_MAX*AVG_LABEL_LEN];
static int  label_pos[LABEL_MAX];
static int  label_val[LABEL_MAX];
static int  label_stat[LABEL_MAX];
static int  label_tab_pos;
static int  labels;
static int  errors,warnings;
static int  labresolved_flag;
static int  data_flag;
static int  buf_bytes;
static int  quiet_mode;
static int  warn_unused;
static int  raw_binary;
static int  pre_proccess;
static int  use_linker;
static char *file_input;
static unsigned char plain_buf[128];
static int  plain_buf_len;
static int  no_jcc;

/* Source line tracking for lupo/luna interaction */

static int pre_line=-1;
static char pre_pedigree[8192]={0};      /* these two *must* be     */
static char pre_prev_pedigree[8192]={1}; /* initialised differently */
int dot_line_count=0; 

#define fl_resolved    0x0001 /* set, if label's value is known */
#define fl_used        0x0002 /* set, if label is used somewhere */
#define fl_global      0x0004 /* set, if label is defined as global */
#define fl_external    0x0008 /* set, if label is undefined */

/* special defines for creation of object-files */

static int  object_mode;

#define fl_variable    0x0010 /* set, if expression depends on org-addr. */
#define fl_extdep      0x0020 /* set, if expr depends on an external label */
#define fl_takelo      0x0040 /* set, if lo-byte of variable value is used */
#define fl_takehi      0x0080 /* set, if hi-byte of variable value is used */
#define fl_forceword   0x0100 /* force putbyte to emmit a word */

#define fl_valdefs     (fl_variable|fl_extdep|fl_takelo|fl_takehi)

/* table of assembler commands and their opcodes */

#define BEF_NUM   151

static char *beflst[BEF_NUM]=
                 {  "cpx","cpx","cpx","cpy","cpy","cpy","bit","bit",
                    "bcc","bcs","beq","bne","bmi","bpl","bvc","bvs",
                    "jmp","jmp","jsr","asl","asl","asl","asl","asl",
                    "lsr","lsr","lsr","lsr","lsr","rol","rol","rol",
                    "rol","rol","ror","ror","ror","ror","ror","clc",
                    "cld","cli","clv","sec","sed","sei","nop","rts",
                    "rti","brk","lda","lda","lda","lda","lda","lda",
                    "lda","lda","ldx","ldx","ldx","ldx","ldx","ldy",
                    "ldy","ldy","ldy","ldy","sta","sta","sta","sta",
                    "sta","sta","sta","stx","stx","stx","sty","sty",
                    "sty","tax","tay","txa","tya","txs","tsx","pla",
                    "pha","plp","php","adc","adc","adc","adc","adc",
                    "adc","adc","adc","sbc","sbc","sbc","sbc","sbc",
                    "sbc","sbc","sbc","inc","inc","inc","inc","dec",
                    "dec","dec","dec","inx","dex","iny","dey","and",
                    "and","and","and","and","and","and","and","ora",
                    "ora","ora","ora","ora","ora","ora","ora","eor",
                    "eor","eor","eor","eor","eor","eor","eor","cmp",
                    "cmp","cmp","cmp","cmp","cmp","cmp","cmp"          };

static unsigned char  befopc[BEF_NUM]=
                {   224, 236, 228, 192, 204, 196,  44,  36,
                    144, 176, 240, 208,  48,  16,  80, 112,
                     76, 108,  32,  14,  30,   6,  22,  10,
                     78,  94,  70,  86,  74,  46,  62,  38,
                     54,  42, 110, 126, 102, 118, 106,  24,
                    216,  88, 184,  56, 248, 120, 234,  96,
                     64,   0, 169, 173, 189, 185, 165, 181,
                    161, 177, 162, 174, 190, 166, 182, 160,
                    172, 188, 164, 180, 141, 157, 153, 133,
                    149, 129, 145, 142, 134, 150, 140, 132,
                    148, 170, 168, 138, 152, 154, 186, 104,
                     72,  40,   8, 105, 109, 125, 121, 101,
                    117,  97, 113, 233, 237, 253, 249, 229,
                    245, 225, 241, 238, 254, 230, 246, 206,
                    222, 198, 214, 232, 202, 200, 136,  41,
                     45,  61,  57,  37,  53,  33,  49,   9,
                     13,  29,  25,   5,  21,   1,  17,  73,
                     77,  93,  89,  69,  85,  65,  81, 201,
                    205, 221, 217, 197, 213, 193, 209                  };

static unsigned char  befatp[BEF_NUM]=
                {     1,   2,   5,   1,   2,   5,   2,   5,
                     10,  10,  10,  10,  10,  10,  10,  10,
                      2,  11,   2,   2,   3,   5,   6,  12,
                      2,   3,   5,   6,  12,   2,   3,   5,
                      6,  12,   2,   3,   5,   6,  12,  13,
                     13,  13,  13,  13,  13,  13,  13,  13,
                     13,  13,   1,   2,   3,   4,   5,   6,
                      8,   9,   1,   2,   4,   5,   7,   1,
                      2,   3,   5,   6,   2,   3,   4,   5,
                      6,   8,   9,   2,   5,   7,   2,   5,
                      6,  13,  13,  13,  13,  13,  13,  13,
                     13,  13,  13,   1,   2,   3,   4,   5,
                      6,   8,   9,   1,   2,   3,   4,   5,
                      6,   8,   9,   2,   3,   5,   6,   2,
                      3,   5,   6,  13,  13,  13,  13,   1,
                      2,   3,   4,   5,   6,   8,   9,   1,
                      2,   3,   4,   5,   6,   8,   9,   1,
                      2,   3,   4,   5,   6,   8,   9,   1,
                      2,   3,   4,   5,   6,   8,   9                  };  

static unsigned char arglen[14]=
               {    4, 2, 3, 3, 3, 2, 2, 2, 2, 2, 0, 3, 1, 1            }; 

static unsigned char hashtab[323]={
          91,255,255,255,255,  8,255,255,255,255,255,255,255,255,255,255,
         255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
         255,255,255,111,255,  9,255,255,255,255,255, 10,255,255,255,255,
         255,255,255,255,119,255,255,255,255,255,255,255, 39,255, 40,255,
          11,255,255, 12,255,  6,255,255, 41,255,255,255,255,116,255,118,
         255,255,255,255,255,255,255,255, 13,255,255,143,255, 19,255,255,
          49,255, 42,255, 14,255,255,255,255,255, 50,255,255,255,255,255,
         255,255,255,255,255,255,255,255,255,255,  0,255,  3,135,255,255,
         255,255,107,255, 15,255,255,255,255,255,255,255,255,255,255,255,
         255,255,255,255,255,255,255,255, 58,255, 63,255,255,255,255,255,
         255, 16,255,255,255,255, 88,255,255,255, 99,255,115,255,117,255,
         255,255,255,255,255,255,255,255,255, 43, 87, 44,255,255,255,255,
         255,255,255, 18, 90, 45,255,255,255,255,255,255,255,255,127,255,
         255,255,255, 46,255,255,255, 24, 89, 81,255, 82,255,255,255,255,
         255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,
         255,255,255, 29,255,255,255,255,255,255,255,255,255,255,255, 34,
          68,255,255,255,255,255, 48,255,255,255,255,255,255,255,255,255,
         255,255,255,255,255,255,255,255,255,255, 47,255,255,255, 83,255,
         255,255,255, 84,255,255,255,255,255,255,255,255,255,255, 75,255,
          78,255,255, 86,255,255,255,255,255,255,255,255,255,255,255,255,
         255,255, 85 };

void Howto()
{
  printf("Luna 6502/10-cross-assembler version 1.31\n");
  printf("Usage:\n");
  printf("  luna [-jlLoOpdqRW] sourcefile\n");
  printf("    -j = no automatic bra->jmp conversion\n");
  printf("    -l labelfile = file to store globals in\n");
  printf("    -L = call lld to link against standard libraries\n");
  printf("    -o outputfile (default is \"c64.out\" or \"c64.o\")\n");
  printf("    -O = create object instead of executable\n");
  printf("    -p = disable pre-proccessing by lupo\n");
  printf("    -dname[=macro] = define macro for lupo\n");
  printf("    -q = quiet mode\n");
  printf("    -R = output raw binary, without 2 byte header (start address)\n");
  printf("    -W = print warnings for unused labels\n");
  exit(1);
}

void error(char *text)
{
#ifndef EMACS_ERRORS
  if (errors==0 && warnings==0 && quiet_mode) 
    printf("luna: In file \"%s\":\n",file_input);

  printf(" error: %s in line %i\n", text, _line);
#else
  if (strcmp(pre_prev_pedigree,pre_pedigree))
    {
      /* Error is in a different file */
      int i=0;
      if (!strlen(pre_pedigree)) strcpy(pre_pedigree,file_input);
      printf("In file ");
      while(i<strlen(pre_pedigree))
	{
	  if (pre_pedigree[i]!=',')
	    printf("%c",pre_pedigree[i]);
	  else
	    printf("\nIncluded from ");
	  i++;
	}
      printf("\n");
      /* Update previous line pedigree */
      strcpy(pre_prev_pedigree,pre_pedigree);
    }
  if (!pre_proccess)
    printf("%s:%d: %s\n",file_input,_line,text);
  else
    {
      int i=0;
      while(i<strlen(pre_pedigree))
	{
	  if (pre_pedigree[i]!=',')
	    printf("%c",pre_pedigree[i]);
	  else
	    break;
	  i++;
	}
      printf(":%d: %s\n",pre_line,text);
    }
#endif
  errors++;
}

void warning(char *text)
{
#ifndef EMACS_ERRORS
  if (warnings==0 && errors==0 && quiet_mode)
    printf("luna: In file \"%s\":\n",file_input);

  printf(" warning: %s in line %i\n", text, _line);
#else
  if (strcmp(pre_prev_pedigree,pre_pedigree))
    {
      /* Error is in a different file */
      int i=0;
      if (!strlen(pre_pedigree)) strcpy(pre_pedigree,file_input);
      printf("In file ");
      while(i<strlen(pre_pedigree))
	{
	  if (pre_pedigree[i]!=',')
	    printf("%c",pre_pedigree[i]);
	  else
	    printf("\nIncluded from ");
	  i++;
	}
      printf("\n");
      /* Update previous line pedigree */
      strcpy(pre_prev_pedigree,pre_pedigree);
    }

  if (!pre_proccess)
    printf("%s:%d: warning: %s\n",file_input,_line,text);  
  else
    {
      int i=0;
      while(i<strlen(pre_pedigree))
	{
	  if (pre_pedigree[i]!=',')
	    printf("%c",pre_pedigree[i]);
	  else
	    break;
	  i++;
	}
      printf(":%d: warning: %s\n",pre_line,text);
    }
#endif
  warnings++;
}

#ifdef debug

void print_flags(int flags)
{
  printf("(");
  if (flags&fl_resolved) printf("res ");
  if (flags&fl_used)     printf("usd ");
  if (flags&fl_global)   printf("glb ");
  if (flags&fl_external) printf("ext ");
  if (flags&fl_variable) printf("var ");
  if (flags&fl_extdep)   printf("edp ");
  if (flags&fl_takelo)   printf("lo ");
  if (flags&fl_takehi)   printf("hi");
  printf(")\n");
}

#endif

int is_sep(int c)
{
  if (c>='0' && c<='9') return 0;
  if (c>='a' && c<='z') return 0;
  if (c>='A' && c<='Z') return 0;
  if (c=='_') return 0;
  if (c=='.') return 0;
  return 1;
}

int Readline()
{
  int x;
  int i;

  x=fgetc(infile);
  i=0;
  while (i<LINE_LEN && x!='\n') {
    if (x==EOF) {
      if (i==0) return (EOF);
      line[i]='\0';
      return (i); }
    line[i]=x;
    i=i+1;
    x=fgetc(infile); }
  line[i]='\0';
  if (x=='\n') return (i);
  /*printf("error: Line to long\n");*/
  error("Line to long");
  exit(1);
}

int nextchar(int i)
{
  while ( line[i]==' ' || line[i]=='\t' ) i++;
  return (i);
}

int nextsep(int i)
{
  int quoted=0;
  while ((line[i]!=' ' && line[i]!='\t' && line[i]!='\0' && line[i]!=';'
                      && line[i]!=',')||quoted)
    {
      if (line[i]=='\"') quoted^=1; /*"*/
      i++;
    }
  return (i);
}

int strwant(int *i, char *text)
{
  int j;
  j=0;
  *i=nextchar(*i);
  while (text[j]!='\0') {
    if (text[j]!=line[*i]) return 0; 
    *i=nextchar(*i+1);
    j=j+1; }
  return 1;
}

#define str_cmp(a,b)  (!strcmp(a,b))

/*
int str_cmp(char *string1, char *string2)
{
  int i;
  i=0;
  while (string1[i]!='\0') {
    if (string1[i]!=string2[i]) return 0;
    i=i+1; }
  if (string2[i]!='\0') return 0;
  return 1;
}
*/

int search_label(char *labname)
{
  int lowerb,i,upperb,tmp;

  lowerb=0; upperb=labels;

  while (lowerb!=upperb) {
    i=(lowerb+upperb)>>1;
    if ((tmp=strcmp(labname,&label_tab[label_pos[i]]))==0) {
      return i; }

    if (upperb-lowerb==1) break;
    if (tmp<0) upperb=i; else lowerb=i;
  }

  return NO_LABEL;
}

int insert_label(char *labname, int *pos)
{
  int lowerb,i,upperb,tmp;
  int tab_pos=label_tab_pos;

  lowerb=0; upperb=labels;
  i=0; tmp=0; *pos=0;

  while (lowerb!=upperb) {
    i=(lowerb+upperb)>>1;
    if ((tmp=strcmp(labname,&label_tab[label_pos[i]]))==0) {
      *pos=i;
      return DUP_LABEL; }

    if (upperb-lowerb==1) break;
    if (tmp<0) upperb=i; else lowerb=i;
   }

  lowerb=0;
  while (labname[lowerb]!='\0') {

    if (label_tab_pos+lowerb>=LABEL_MAX*AVG_LABEL_LEN) {
      error("label-space overflow");
      return 0; }

    label_tab[label_tab_pos+lowerb]=labname[lowerb];
    lowerb++;

    if (lowerb==LABEL_LEN) {
      error("label too long");
      return 0; }
    }

  if (labels>=LABEL_MAX) {
    error("too many labels");
    return 0; }

  label_tab[label_tab_pos+lowerb]='\0';
  label_tab_pos+=lowerb+1;

  if (tmp>0) i++;
  if (i==labels) {
    label_pos[labels]=tab_pos;
    *pos=labels++;
    return 0; }

  /* insert at position i */

  tmp=labels;
  while (tmp>i) {
    label_pos[tmp]=label_pos[tmp-1];
    label_val[tmp]=label_val[tmp-1];
    label_stat[tmp]=label_stat[tmp-1];
    tmp--; }

  label_pos[i]=tab_pos;
  labels++;
  *pos=i;
  return 0;
}

void setlabel(char *labname, unsigned long val, int flags)
{
  int i;

  if (flags&(fl_extdep)) {
    error("external in label-definition");
    return; }

  /* search for label in database */

  if (insert_label(labname,&i)==DUP_LABEL) {

    if (pass==1) {
      sprintf(msgbuf,"duplicated label \"%s\"",labname);
      error(msgbuf);
      return; }

    if ((flags&fl_resolved)==0) { 
      /* val of label is not valid, because there have been unknown
         labels in expression, so clear bit */
      label_stat[i]&=~fl_resolved;
      if (final_pass) {
        sprintf(msgbuf,"label \"%s\" is unresolvable",labname);
       error(msgbuf); }
#     ifdef debug
      printf("label \"%s\" stays undefined\n",labname);
#     endif
	  return; }

    if (label_val[i]!=val) {
      label_val[i]=val;
      if (final_pass) {
        sprintf(msgbuf,"divergent labelvalue (%s)",labname);
        error(msgbuf); }
      if (label_stat[i]&fl_variable) labresolved_flag=1;
      alter_flag=1; }
    label_stat[i]=(label_stat[i]&~fl_valdefs)|(flags&fl_valdefs);
    if ((label_stat[i]&fl_resolved)==0) { 
      labresolved_flag=1;
      label_stat[i]=label_stat[i]|fl_resolved; }

    if (final_pass && warn_unused && (label_stat[i]&fl_used)==0 \
        && !(object_mode && label_stat[i]&fl_global)) {
      sprintf(msgbuf,"unused label \"%s\"",&label_tab[label_pos[i]]);
      warning(msgbuf); }

#   ifdef debug
    printf("set \"%s\"=$%lx ",labname,val); 
    print_flags(label_stat[i]);
#   endif
    return; }


  label_val[i]=val;
  if (!(flags&fl_resolved)) 
    label_stat[i]=0;           /* value undefined, not global */
  else { 
    label_stat[i]=(flags&(fl_valdefs|fl_external))|fl_resolved;  /* not global nor used   */
    labresolved_flag=1; }

  alter_flag=1;

# ifdef debug
  printf("create[%i] \"%s\"=$%lx ",i,labname,val);
  print_flags(label_stat[i]);
# endif
}

/* getascii does ascii-petscii conversion only if flag is set */

int getascii(int i,int *par,int flag)
{
  if (line[i]=='\"') {                            /*"*/
    error("Illegal character constant");
    *par=0;
    return i+1; }
  if (line[i]=='\\') {
    i=i+1;
	switch (line[i]) {
	  case 'r'  : { *par=13; break; }
	  case 'n'  : { *par=10; break; }
	  case 't'  : { *par=9; break; }
	  case '0'  : { *par=0; break; }
	  case '\\' : { *par='\\'; break; }
	  case '\"' : { *par=34; break; }
	  default   : { error("unknown char"); *par=line[i]; } }
	return i+1; }

  *par=line[i];

  if (flag) {
    /* convert lower to upper case... */
    if (*par>='a' && *par<='z') *par=*par-'a'+'A';
    else if (*par>='A' && *par<='Z') *par=*par-'A'+'a';
  }

  return i+1; 
}

/* getaascii, apple ascii - slightly different than c64/c128 */

int getaascii(int i,int *par)
{
  if (line[i]=='\"') {                            /*"*/
    error("Illegal character constant");
    *par=0;
    return i+1; }
  if (line[i]=='\\') {
    i=i+1;
        switch (line[i]) {
          case 'n'  : { *par=141; break; }
          case 't'  : { *par=137; break; }
          case '0'  : { *par=0; break; }
          case '\\' : { *par='\\'; break; }
          case '\"' : { *par=162; break; }
          default   : { error("unknown char"); *par=line[i]; } }
        return i+1; }

  *par=line[i]+128;
  return i+1;
}

void setglobal(char *str)
{
  int i;

# ifdef debug
  printf("global: \"%s\"\n",str);
# endif

  if((i=search_label(str))!=NO_LABEL) 
    label_stat[i]|=fl_global; /* set global-bit */
  else {
    unknown_flag=1;
#   ifdef debug
    printf("unknown global\n");
#   endif
    if (pass>1) {
      sprintf(msgbuf,"undefined global \"%s\"",str);
      error(msgbuf); }
  }
  return;
}

int getlabel(char *str)
{
  int i;
  i=0;

# ifdef debug
  printf("getlabel \"%s\"\n",str);
# endif

  if ((i=search_label(str))!=NO_LABEL) {
   label_stat[i]|=fl_used;

#  ifdef debug
   if ((label_stat[i]&fl_resolved)==0) {
     printf("unresolved label in expression\n"); }
#  endif

   return i; }

  unknown_flag=1;
# ifdef debug
  printf("label %s unknown\n",str);
# endif
  if (pass>1) {
    setlabel(str,0,fl_external|fl_resolved);
    labresolved_flag=1;
    if (!object_mode) {
      sprintf(msgbuf,"undefined label \"%s\" (only reported once)",str);
      error(msgbuf); }
    else {
#     ifdef debug
      printf("added \"%s\" as external label\n",str);
#     endif
      return search_label(str); } }

  return NO_LABEL;
}

int getval(int i, unsigned long *val, int *flags, int *lab)
{
  int cnt;
  int hlp;
  int tmp;
  char str[8];

  *val=cnt=*flags=0;
  *lab=NO_LABEL;

  if (line[i]=='\0') {
    error("expression expected");
    return i; }

  if (line[i]=='*') {
    /* "*" means value of PC */
    i=i+1;
    *val=pc;
    *flags=fl_variable|fl_resolved;
    return i; }

  /* check if its the "+" or "-" shortcut */
  if (line[i]=='+') {
    /* is a "+..." shortcut */
    while (line[i]=='+') {
      cnt=cnt+1;
      i=i+1; }
    sprintf(str,"_+%i",fmark+cnt-1);
    hlp=getlabel(str);
    if (hlp!=NO_LABEL) {
      *val=label_val[hlp];
      *flags=fl_variable|fl_resolved; }
    return i; }

  if (line[i]=='-') {
    /* is a "-..." shortcut */
    while (line[i]=='-') {
      cnt=cnt+1;
      i=i+1; }
    sprintf(str,"_-%i",rmark-cnt);
    hlp=getlabel(str);
    if (hlp!=NO_LABEL) {
      *val=label_val[hlp];
      *flags=fl_variable|fl_resolved; }
    return i; }
  
  if (line[i]=='#' || (line[i]>='0' && line[i]<='9')) {
    /* get decimal value */
    if (line[i]=='#') i=nextchar(i+1);
    while (!is_sep(line[i])) {
      if (line[i]>='0' && line[i]<='9') hlp=line[i]-'0';
      else { cnt=0; break; }
      *val=*val*10+hlp;
      cnt=cnt+1;
      i=i+1; }
    if (cnt==0) error("decimal expected");
    else *flags=fl_resolved;
    return i; }

  if (line[i]=='$') {
    /* get hex value */
    i=nextchar(i+1);
    while (!is_sep(line[i])) {
      if (line[i]>='0' && line[i]<='9') hlp=line[i]-'0';
      else if (line[i]>='a' && line[i]<='f') hlp=line[i]-'a'+10;
      else if (line[i]>='A' && line[i]<='F') hlp=line[i]-'A'+10;
      else { cnt=0; break; }
      *val=*val*16+hlp;
      cnt=cnt+1;
      i=i+1; }
    if (cnt==0) error("hex expected");
    else *flags=fl_resolved;
    return i; }

  if (line[i]=='\"') {
    /* get character value */
    i=getascii(i+1,&tmp,0); *val=tmp;   /* plain ascii, no conversion */
    if (strwant(&i,"\"")) *flags=fl_resolved;
    else error("unterminated character constant");
    return i; }

  if (line[i]=='%') {
    /* get binary value */
    i=nextchar(i+1);
    while (!is_sep(line[i])) {
      if (line[i]=='0') hlp=0;
      else if (line[i]=='1') hlp=1;
      else { cnt=0; break; }
      *val=*val*2+hlp;
      cnt=cnt+1;
      i=i+1; }
    if (cnt==0) error("binary expected");
    else *flags=fl_resolved;
    return i; }

  /* nothing of the obove, so it must be a label */

  cnt=i;
  while (!is_sep(line[cnt])) cnt=cnt+1;
  tmp=line[cnt];
  line[cnt]='\0';
  /* now try to find a label that matches */
  hlp=getlabel(&line[i]);
  if (hlp!=NO_LABEL) {
    *val=label_val[hlp];
    *flags=label_stat[hlp];
    if (*flags&fl_external) {
      *val=0;
      *lab=hlp;
      *flags=(*flags&~fl_variable)|fl_extdep; }
    }

  line[cnt]=tmp;
  return cnt;
}

int getterm(int i, unsigned long *val, int *flags, int *lab)
{
  i=nextchar(i);

  if (line[i]=='<') {
    /* take lowbyte of term */
    i=getterm(i+1, val, flags, lab);
    if (object_mode && *flags&(fl_variable|fl_extdep)) {
      if (*flags&(fl_takelo|fl_takehi)) error("invalid expression");
      else *flags|=fl_takelo; }
    else *val=*val&255;
    return i; }

  if (line[i]=='>') {
    /* take highbyte of term */
    i=getterm(i+1, val, flags, lab);
    if (object_mode && *flags&(fl_variable|fl_extdep)) {
      if (*flags&(fl_takelo|fl_takehi)) error("invalid expression");
      else *flags|=fl_takehi; }
    else *val=(*val>>8);
    return i; }

  if (line[i]=='~') {
    /* invert result (8bit only) */
    i=getterm(i+1, val, flags, lab);
    if (object_mode && *flags&(fl_variable|fl_extdep))
      error("invalid expression");
    if (*val>255) error("\"~\" is an 8bit operator");
    else *val=255-*val;
  return i; }

  if (line[i]=='(') {
    i=getexpr(i+1, val ,flags, lab);
    if (!strwant(&i,")")) error("\")\" expected");
    return i; } 

  if (line[i]=='[') {
    i=getexpr(i+1, val ,flags, lab);
    if (!strwant(&i,"]")) error("\"]\" expected");
    return i; }

  return getval(i, val, flags, lab);
}
  
int getexpr(int i, unsigned long *val, int *flags, int *lab)
{
  unsigned long tmp_val;
  int tmp_flags;
  int tmp_lab;

# ifdef debug
  printf("expr:\"%s\"\n",&line[i]);
# endif

  i=getterm(i, val, flags, lab);

  while (1) {

    i=nextchar(i);
    if (line[i]=='+') {
      i=getterm(i+1, &tmp_val, &tmp_flags, &tmp_lab);
      if (!(tmp_flags&*flags&fl_resolved)) {
        *flags=0; continue; }
      if (!object_mode) *val+=tmp_val;
      else {
        if ((tmp_flags|*flags)&(fl_takelo|fl_takehi)) 
          error("invalid expression");
        else if (!(*flags&fl_valdefs)) {
          *val+=tmp_val;
          *flags=tmp_flags;
          *lab=tmp_lab; }
        else if (!(tmp_flags&fl_valdefs)) {
          *val+=tmp_val; }
        else {
          *flags=0;
          error("invalid expression"); }
	    }
      continue; }

    if (line[i]=='-') {
      i=getterm(i+1, &tmp_val, &tmp_flags, &tmp_lab);
      if (!(tmp_flags&*flags&fl_resolved)) {
        *flags=0; continue; }
      if (!object_mode) *val=*val-tmp_val;
      else {
        if ((tmp_flags|*flags)&(fl_takelo|fl_takehi)) 
          error("invalid expression");
        else if (!(*flags&fl_valdefs)) {
          *val-=tmp_val;
          *flags=tmp_flags;
          *lab=tmp_lab; }
        else if (!(tmp_flags&fl_valdefs)) {
          *val-=tmp_val; }
        else if (*flags&tmp_flags&fl_variable) {
          *val-=tmp_val;
          *flags=fl_resolved; }
        else {
          *flags=0;
          error("invalid expression"); }
	    }
      continue; }

    if (line[i]=='|') {
      i=getterm(i+1, &tmp_val, &tmp_flags, &tmp_lab);
      if (!(tmp_flags&*flags&fl_resolved)) {
        *flags=0; continue; }
      if (!object_mode) *val=*val|tmp_val;
      else {
        if ((tmp_flags|*flags)&(fl_takelo|fl_takehi|fl_extdep|fl_variable)) 
          error("invalid expression");
        else *val=*val|tmp_val; }
      continue; }

    if (line[i]=='&') {
      i=getterm(i+1, &tmp_val, &tmp_flags, &tmp_lab);
      if (!(tmp_flags&*flags&fl_resolved)) {
        *flags=0; continue; }
      if (!object_mode) *val=*val&tmp_val;
      else {
        if ((tmp_flags|*flags)&(fl_takelo|fl_takehi|fl_extdep|fl_variable)) 
          error("invalid expression");
        else *val=*val&tmp_val; }
      continue; }

    if (line[i]=='^') {
      i=getterm(i+1, &tmp_val, &tmp_flags, &tmp_lab);
      if (!(tmp_flags&*flags&fl_resolved)) {
        *flags=0; continue; }
      if (!object_mode) *val=*val^tmp_val;
      else {
        if ((tmp_flags|*flags)&(fl_takelo|fl_takehi|fl_extdep|fl_variable)) 
          error("invalid expression");
        else *val=*val^tmp_val; }
      continue; }

    /* PGS : > operator (shift right n times) */
    if (line[i]=='>') {
      i=getterm(i+1, &tmp_val, &tmp_flags, &tmp_lab);
      if (!(tmp_flags&*flags&fl_resolved)) {
        *flags=0; continue; } /* return unresolved if either argument is */
      if (!object_mode) *val=*val>>tmp_val;
      else {
        if ((tmp_flags|*flags)&(fl_takelo|fl_takehi|fl_extdep|fl_variable)) 
          error("invalid expression");
        else *val=*val>>tmp_val; }
      continue; }

    /* < operator (shift left n times) */
    if (line[i]=='<') {
      i=getterm(i+1, &tmp_val, &tmp_flags, &tmp_lab);
      if (!(tmp_flags&*flags&fl_resolved)) {
        *flags=0; continue; } /* return unresolved if either argument is */
      if (!object_mode) *val=*val<<tmp_val;
      else {
        if ((tmp_flags|*flags)&(fl_takelo|fl_takehi|fl_extdep|fl_variable)) 
          error("invalid expression");
        else *val=*val<<tmp_val; }
      continue; }

    break; }

# ifdef debug
  printf("expression is: val=$%lx, lab=%i, flags=",*val,*lab);
  print_flags(*flags);
# endif

  return i;
}


int getasspar(int i, int *mode, int *par, int *flags, int *lab)
{
  unsigned long ltmp;
  int tmp;
  i=nextchar(i); 
  *flags=0;
  if (line[i]=='\0') { *mode=13; return i; }
  if (line[i]==',' || line[i]==';') { *mode=13; return i; }

  if (line[i]=='(') {
    /* (expr,x) or (expr),y or (expr) */
    i=nextchar(i+1);
    if (line[i]=='\0') { *mode=13; error("stray \"(\" found"); return i; }
    i=getexpr(i,&ltmp,flags,lab);
	if ( (*flags&fl_extdep)?(ltmp>0x7fff && ltmp<0xffff8000):(ltmp>0xffff) )
	  error("word out of range.");
	*par=ltmp;
    i=nextchar(i);
    if (line[i]=='\0' || line[i]==';') { 
      *mode=2; error("missing \")\""); return i; }

    if (line[i]==')') {
      i=nextchar(i+1);
      if (line[i]==',') {
        /* must be (expr),y */
        *mode=9;
        if (!strwant(&i,",y")) error("expected \",y\"");
        return i; }
      else {
        /* must be (expr) */
        *mode=11;
        return i; } }

    /* must be (expr,x) */
    *mode=8;
    if (!strwant(&i,",x)")) error("expected \",x)\"");
    return i; }

  if (line[i]=='a' && (line[i+1]==' '|| line[i+1]=='\t' || line[i+1]=='\0'
                                     || line[i+1]==';'  || line[i+1]==':' )) {
    *mode=12; return nextchar(i+1); }

  if (line[i]=='#') {
    *mode=1;
    i=getexpr(i+1,&ltmp,flags,lab);
	if (ltmp>0xff && !(*flags&(fl_takelo|fl_takehi))) 
	  error("word out of range");
	*par=ltmp;
    i=nextchar(i);
    return i; }

  if ((tmp=(line[i]=='.'))) i=nextchar(i+1);
  i=getexpr(i,&ltmp,flags,lab);
  if ( (*flags&fl_extdep)?(ltmp>0x7fff && ltmp<0xffff8000):(ltmp>0xffff) )
	error("word out of range.");
  *par=ltmp;
  i=nextchar(i);
  if (   !(((*par&0xff00)==0) && (*flags&fl_resolved)) 
      || tmp
      || (object_mode&&(*flags&fl_variable))
      || *flags&fl_extdep) 
       *mode=2; /* word */
  else *mode=5; /* byte */

  if (line[i]!='\0') {
    if (line[i]==',') {
      i=nextchar(i+1);
      if (line[i]=='\0') { error("stray \",\""); return i; }
      if (line[i]=='x') *mode=*mode+1;
      else if(line[i]=='y') *mode=*mode+2;
      else error("unknown index");
      i=nextchar(i+1); }}
  return i;
}

void raw_put(int x)
{
# ifdef debug
  printf("*** writing %i\n",x);
# endif

  if ((x&0xff00)!=0) { 
    error("expression out of range");
    return; }
  if (fputc(x,binfile)==EOF) {
    printf("i/o-error while writing to outputfile\n");
    exit(1); }
  code_length++;
}

void cleanup_plain_buf()
{
  int i;

  if (plain_buf_len==0) return;
  raw_put(plain_buf_len);
  i=0;
  while (i<plain_buf_len) raw_put((int) plain_buf[i++]);
  plain_buf_len=0;
}
  
void putbyte(int i,int flags, int lab)
{
  int x,y;

  if (final_pass) {
    if (org_lock==0) {
      pc_begin=pc;
      if (object_mode) {

        if (lunix_mode) raw_put('O'); else raw_put('o');
        raw_put('b');
        raw_put('j');

#       ifdef debug

        printf("object header\n");
        printf("  globals:\n");

#       endif

        x=0;
        while (x<labels) {
          if (label_stat[x]&fl_global) {
            if (label_stat[x]&fl_external) {
              if (!quiet_mode) 
                printf("  note: undefined global \"%s\" considered external\n",&label_tab[label_pos[x]]); }
            else {
#             ifdef debug
			  printf("    %s=%i\n",&label_tab[label_pos[x]],label_val[x]);
#             endif
			  fprintf(binfile,"%s",&label_tab[label_pos[x]]);
			  code_length+=strlen(&label_tab[label_pos[x]]);
			  raw_put(0);
			  raw_put(label_val[x]&0xff);
			  raw_put((label_val[x]>>8)&0xff); }}
          x++; }
#       ifdef debug
        printf("code-length=%i\n",pc_end);
        printf("  externals=\n");
#       endif
        raw_put(0);
        raw_put(pc_end&0xff);
        raw_put((pc_end>>8)&0xff);
        x=0; y=0;
        while (x<labels) {
          if (label_stat[x]&fl_external) {
#           ifdef debug
            printf("*** [%2i] \"%s\"\n",y,&label_tab[label_pos[x]]);
#           endif
            fprintf(binfile,"%s",&label_tab[label_pos[x]]);
            code_length+=strlen(&label_tab[label_pos[x]]);
            raw_put(0);
            label_val[x]=y++; }
          x++; }
#       ifdef debug
        printf("\n");
#       endif
        raw_put(0); }
      else {
        if (!lunix_mode) {
          x=pc-buf_bytes;
#         ifdef debug
          printf("code starts at %i\n",x);
#         endif
          if (x==0) warning("missing org directive, assume \"org $0000\"");
          if (!raw_binary) {
            raw_put(x&0xff);
            raw_put((x>>8)&0xff); }
          }
        else {
          raw_put(0xff);
          raw_put(0xff); } }
	}
#   ifdef debug
    printf("### byte=%i lab=%i flags=",i,lab);
    print_flags(flags);
#   endif

    if (!object_mode) {
      /* insert buffer bytes if there are */
      if (buf_bytes!=0) {
#       ifdef debug
        printf("### inserting %i-buffer bytes\n",buf_bytes);
#       endif
        x=0;
        while (x<buf_bytes) {
          raw_put(0);
          x=x+1; } }
      /* continue with actual stuff */
      raw_put(i); }
    else {
      /* insert buffer bytes if there are */
      if (buf_bytes!=0) {
#       ifdef debug
        printf("### inserting %i-buffer bytes\n",buf_bytes);
#       endif
        x=0;
        while (x<buf_bytes) {
          plain_buf[plain_buf_len++]=0;
          if (plain_buf_len==127) cleanup_plain_buf();
          x=x+1; } }
      /* continue with actual stuff */
      if ((flags&fl_valdefs)==0) {
        plain_buf[plain_buf_len++]=(unsigned char) i;
        if (plain_buf_len==127) cleanup_plain_buf(); }
      else {
        cleanup_plain_buf();
        if (flags&fl_takelo) x=0x01;
        else if (flags&fl_takehi) x=0x02;
        else { x=0x03; 
          if (!(flags&fl_forceword)) 
            error("byte out of range (variables/externals are 16bit)"); }
        if (flags&fl_variable) {
          raw_put(0x80|x);
          raw_put(i&0xff);
          raw_put((i>>8)&0xff); }
        else if (flags&fl_external) {
          if (i==0) {
            raw_put(0xc0|x);
            raw_put(label_val[lab]&0xff);
            raw_put((label_val[lab]>>8)&0xff); }
          else {
            raw_put(0xd0|x);
            raw_put(label_val[lab]&0xff);
            raw_put((label_val[lab]>>8)&0xff);
            raw_put(i&0xff);
            raw_put((i>>8)&0xff); } }
        else error("internal assembler error"); }
      }
    }
  org_lock=1;
  pc++;
  buf_bytes=0;
}

void putword(int word,int flags, int lab)
{
  if (!object_mode || (flags&fl_valdefs)==0) {
    putbyte(word&0xff,fl_resolved,0);
    putbyte((word>>8)&0xff,fl_resolved,0);
    return; }

  if (flags&(fl_takelo|fl_takehi)) {
    error("byte instead of word");
    return; }

  putbyte(word,flags|fl_forceword,lab);
  pc++;
}

void writebef(int opcode, int bef_atp, int par, int flags, int lab)
{
  int tmp;

  tmp=arglen[bef_atp];

  if (tmp==1) putbyte(opcode,fl_resolved,0);
  else if (tmp==2) {
    putbyte(opcode,fl_resolved,0);
    putbyte(par,flags,lab); }
  else if (tmp==3) {
    putbyte(opcode,fl_resolved,0);
    putword(par,flags,lab); } 
  else if (tmp==0) {
    /* relative jump, if out of range then replace by long
       range jump.

         eg. beq label -> bne *+5
                          jmp label   */

    if ((flags&fl_resolved)==0) { par=pc+2; return; }
                    /* don't make far jumps, if address in unknown */
    if (flags&fl_extdep) {
      if (object_mode) tmp=257;
      else { pc=pc+2; return;} }
    else if (par>=pc+2) {
      tmp=par-pc-2;
      if (tmp>127) tmp=256;
      else {
        putbyte(opcode,fl_resolved,0);
        putbyte(tmp,fl_resolved,0); } }
    else {
      tmp=pc+2-par;
      if (tmp>128) tmp=256;
      else {
        putbyte(opcode,fl_resolved,0);
        putbyte(256-tmp,fl_resolved,0); } }
    if (tmp>=256) {
      if (no_jcc) { 
        pc=pc+2; 
        if (final_pass) error("relative jump out of range");
        return; }
      if (final_pass) { 
        if (tmp==256) warning("relative jump out of range");
        else warning("conditional jump to external"); }
      putbyte(opcode^32,fl_resolved,0);
      putbyte(3,fl_resolved,0);
      putbyte(76,fl_resolved,0);
      putword(par,flags,lab); }
    }
  else printf("internal error tmp=%i\n",tmp);
}

void setsigjmp(char *signame, int pos)
{
  int i;
 
  if ((i=search_label(signame))==NO_LABEL) {
    if (final_pass) {
      if (!quiet_mode) 
        printf(" note: ignored unused system vector \"%s\"\n",signame); }
    return; }

  header[pos*3+8]=76;
  header[pos*3+9]=label_val[i]&255;
  if ((label_stat[i]&fl_resolved)==0) {
    sprintf(msgbuf,"undefined systemvector \"%s\"",signame);
    error(msgbuf); }
  label_stat[i]=label_stat[i]|fl_used;
  header[pos*3+10]=(label_val[i]>>8)&255;
} 

/* return a unique filename */

char *my_tmpnam(char * base)
{
  char *tmp;
  char *result;

  /* This should be unique */
  tmp=tmpnam((char*)NULL); /* sorry, can't use mkstemp */
  if (tmp==NULL) {
    /* if tmpnam can't generate a filename (?) we'll do it on our own! */
    char str[40];
#   ifdef _AMIGA
    static tmpcount=0;
    sprintf(str,"%s%i.tmp",base,tmpcount++);
#   else
    sprintf(str,"/tmp/%s.%d",base,(int)getpid());
#   endif
    result=(char *)malloc((strlen(str)+1)*sizeof(char));
    strcpy(result,str);
    return result; 
  }

  result=(char *)malloc((strlen(tmp)+1)*sizeof(char));
  strcpy(result,tmp);

  return result;
}

int addopt(char *str1, int pos, char *str2)
{
  str1[pos++]='-';
  strcpy(&str1[pos],str2);
  pos+=strlen(str2);
  str1[pos]=' ';
  return pos+1;
}

int main(int argc, char **argv)
{
  static int llen;
  static int i,j,p,q;
  static char str[100];
  static int mode;
  static int par;
  static int tmp;
  static int dseg_count;
  static char *file_output;
  static char *file_labels;
  static int  flags,lab;
  static char *pre_file;
  static char *tmpobj_file=NULL;
  static char lupo_options[1024];
  const char* hex_table="0123456789ABCDEF";

  pass=final_pass=0;
  alter_flag=unknown_flag=1;
  quiet_mode=no_jcc=0;
  labels=0;
  rmarks=fmarks=0;
  errors=warnings=0;
  label_tab_pos=0;
  labresolved_flag=1;
  file_input=file_output=file_labels=NULL;
  object_mode=0;
  plain_buf_len=0;
  code_length=0;
  pre_proccess=1;
  use_linker=0;
  raw_binary=0;
  warn_unused=1;

  i=0;
  while (i<64) {
    header[i]=0;
    i=i+1; }

  q=0; /* q is length of lupo_option_string */
  i=1; 
  while ( i<argc ) {
    if (argv[i][0]=='-') {
      j=1;
      while (argv[i][j]!='\0') {
        switch (argv[i][j]) {
          case 'R': { raw_binary=1; break; }
          case 'W': { warn_unused=1; break; }
          case 'q': { quiet_mode=1; warn_unused=0; break; }
          case 'l': { i++; file_labels=argv[i]; j=0; break; }
          case 'L': { use_linker=1; object_mode=1; break; }
          case 'o': { i++; file_output=argv[i]; j=0; break; }
          case 'O': { object_mode=1; break; }
          case 'j': { no_jcc=1; break; }
          case 'p': { pre_proccess=0; break; }
			/* options, that are passed through to lupo */
		  case 'd': { q=addopt(lupo_options,q,&(argv[i])[j]); j=0; break; }
          default:  Howto();
          }
        if (i==argc) Howto();
        if (j==0) break;
        j++; }
	} else {
      if (file_input!=NULL) Howto();
      file_input=argv[i]; }
    i++; }
  lupo_options[q]='\0';

  if (file_input==NULL) { printf("%s: No input file\n",argv[0]); exit(1); }
  if (file_output==NULL) {
    if (object_mode) file_output="c64.o"; 
    else             file_output="c64.out"; }

  if (str_cmp(file_input,file_output)) {
    printf("warning: sourcefile=destfile ??\n");
    exit(1); }
  
  /* Call lupo to pre-proccess if necessary */
  if (pre_proccess)
    {
      
      /* Pre-process */
      char temp[1024];
      pre_file=my_tmpnam("lupo");
      
      /* Make lupo command */
      sprintf(temp,"lupo -ql %s -o %s %s",file_input,pre_file,lupo_options);
      /* run command */
      if (!quiet_mode) printf("calling lupo to pre-proccess file\n");
      if (system(temp)) {
        /* Lupo had some error */
        unlink(pre_file);
        printf("%s: lupo returned with error, no output created\n",argv[0]);
        exit(1); } }
  
  do {
    if ((alter_flag==0 || unknown_flag==0) && !labresolved_flag) final_pass=1;
#   ifdef debug
    printf("runtimeflags: alter:%i unknown:%i labresolved:%i\n",alter_flag,unknown_flag,labresolved_flag);
#   endif
    alter_flag=unknown_flag=0;
    _line=0;
    rmark=fmark=0;
    pc=0;
    org_lock=0;
    labresolved_flag=0;
    data_flag=0;
    dseg_count=0;
    buf_bytes=plain_buf_len=0;
    pass=pass+1;
    
    /* open assembler source-file */
    if (pre_proccess) infile=fopen(pre_file,"r"); 
    else              infile=fopen(file_input,"r");

    if (infile==NULL) {
      printf("%s: error: Can't open \"%s\"\n",argv[0],file_input);
      exit(1); }

#   ifdef debug
    printf("\n\n");
#   endif

    if (!final_pass) {
      if (!quiet_mode) printf("Pass %i\n",pass); }

    else {
      if (!quiet_mode) printf("Final pass\n");
      if (use_linker) {
        if (tmpobj_file==NULL) tmpobj_file=my_tmpnam("luna");
        if ((binfile=fopen(tmpobj_file,"wb"))==NULL) {
          printf("%s: can't create temporary objectfile\n",argv[0]);
          exit(1); }}
      else {
        if ((binfile=fopen(file_output,"wb"))==NULL) {
          printf("%s: can't create \"%s\"\n",argv[0],file_output); 
          exit(1); }}
    } 

    while ( (llen=Readline())!=EOF ) {
      _line++;
#     ifdef debug
      printf("line \"%s\" pc=$%x\n",line,pc);
#     endif
      if ((llen=0)) continue;
      if (line[0]==';') continue;
      
      /* extract first identifier */

      i=0;
      j=0;
      while (line[i]!='\0') {
        i=nextchar(j);
        if (line[i]=='\0') continue;
        if (line[i]==':') {
          j=nextchar(i+1);
          continue; }                
        j=nextsep(i);
#       ifdef debug
        printf("working at \"%s\"\n",&line[i]);
#       endif
        if (line[i]==';') break;  /* keine Befehle mehr in dieser Zeile */
        if (line[i]=='.') {
	  unsigned long ltmp;
	  
          /* special assembler commands like .byte .word .asc .head */

          i=i+1;
          if (line[i]=='b' && line[i+1]=='y') {

            /* assume .byte */

            while (1) {
              j=nextchar(j);
              j=getexpr(j,&ltmp,&flags,&lab);
	      if (ltmp>0xffff) error("byte out of range");
              if (object_mode && flags&(fl_variable|fl_extdep)) {
                if (!(flags&(fl_takelo|fl_takehi))) {
                  error("byte out of range"); } }
              else if (ltmp>255) error("byte out of range");
              putbyte(ltmp,flags,lab);
              if (line[j]!=',') break;
              if (lunix_mode && data_flag==0) error("data in code-area");
              j=j+1; }
	    continue; }

          if (line[i]=='d' && line[i+1]=='i') {

            /* assume .digit */

            while (1) {
              j=nextchar(j);
              j=getexpr(j,&ltmp,&flags,&lab);
			  if (ltmp>0xffff) error("byte out of range");
              if (object_mode && flags&(fl_variable|fl_extdep)) {
                if (!(flags&(fl_takelo|fl_takehi))) {
                  error("digit out of range"); } }
              else if (ltmp>15) error("digit out of range");
              putbyte(hex_table[ltmp],flags,lab);
              if (line[j]!=',') break;
              if (lunix_mode && data_flag==0) error("data in code-area");
              j=j+1; }
		    continue; }

          if (line[i]=='w') {

            /* assume .word */

            if (lunix_mode && data_flag==0) error("data in code-area");
            while (1) {
              j=nextchar(j);
              j=getexpr(j,&ltmp,&flags,&lab);
	      if ( (flags&fl_extdep)?
		   (ltmp>0x7fff && ltmp<0xffff8000):(ltmp>0xffff) )
		error("word out of range.");
              putword(ltmp,flags,lab);
              if (line[j]!=',') break;
              j=j+1; }
            continue; }

          if (line[i]=='a') {

            /* assume .asc or .aasc */

            j=nextchar(j);
            if (line[j++]!='\"') error("\" expected");
            if (lunix_mode && data_flag==0) error("string in code-area");
            while (1) {
              if (line[j]=='\"') {                           /*"*/
                j=j+1;
                break; }
              if (line[j]=='\0') {
                error("unterminated string");
                break; }
              if (line[i+1]=='a')
		j=getaascii(j,&par); /* assume .aasc */
	      else
		j=getascii(j,&par,1); /* do ascii-petscii conversion */
              putbyte(par,fl_resolved,0); }
            continue; }

		/*
		  start .header directive
		*/

          if (line[i]=='h') {

#if 1
            /* LUnix .header creator */

            if (org_lock) {
              error("nested org (in header)");
              continue; }
            if (buf_bytes!=0) error(".header after .buf");
            if (!object_mode) pc=4096; /* defaul org-address */
            pc_begin=pc;
            if (pass==1) pc_end=pc_begin;
            lunix_mode=1;
            j=nextchar(j);
            if (!strwant(&j,"\"")) {
              error("CMD-name expected");
              continue; }
            p=0;
            while (1) {
              if (line[j]=='\"') {                   /*"*/
                if (p<8) header[56+p]=0;
                j++;
                break; }
              if (is_sep(line[j])) {
                error("unterminated CMD-name");
                break; }
              j=getascii(j,&header[56+p],1); /* do ascii-petscii conversion */
              p++;
              if (p>8) {
                error("CMD-name too long (8 chars max)");
                break; }
            }
            p=217; /* default zeropage startaddress */
            while (1) {
			  int size;
              j=nextchar(j);
              if (line[j]=='\0') break;
              if (line[j]==';')  break;
              if (line[j]!=',') {
                error("syntax error");
                break; }
              j=nextchar(j+1);
              q=nextsep(j);
              tmp=line[q];
              line[q]='\0';
              if (line[j]=='.') {
		j++;
		if (line[j]=='.') {
		  j++;
		  size=4; } /* ZP-label with .. prefix (allocate 4 bytes) */
		else
		  size=2; } /* ZP-label with . prefix (allocate 2 bytes) */
	      else
		size=1;     /* ZP-label without prefix (allocate 1 byte) */

	      setlabel(&line[j],p,fl_resolved);
	      p+=size;
              line[q]=tmp;
              j=q; }
            header[1]=1;
            header[4]=200-(p-217);
            header[5]=217;
            header[6]=p-217;
            header[2]=1+((pc_end-pc_begin)>>8);
            header[8]=28;
            header[9]=64;
            header[10]=0;
            /* insert optional sig-jumps */
            setsigjmp("_sig.userbreak",6);
            setsigjmp("_sig.killedparent",7);
            setsigjmp("_sig.killedchild",8);
            setsigjmp("_cleanup",9);
            /*  These next two are for drivers only,
                and they *must* be defined for them  */
            setsigjmp("_sig.pload",1);
            setsigjmp("_prockilled",15);

            /* write header */

            i=0;while (i<64) {
              putbyte(header[i],fl_resolved,0);
              i=i+1;
		    }

            i=getlabel("_init");
            flags=0; lab=0;
            if (i!=NO_LABEL) {
              par=label_val[i];
              flags=label_stat[i];
              if (flags&fl_external) error("missing _init label"); }
            else par=0;
            if (i!=NO_LABEL) i=label_val[i]; else i=0;
            putbyte(169,fl_resolved,0);
            putbyte((pc_begin)>>8 &255,fl_resolved,0);
            putbyte(32,fl_resolved,0);        /* instert lda #>pc_begin   */
            putbyte(81,fl_resolved,0);        /*         jsr $9051        */
            putbyte(144,fl_resolved,0);       /*         jmp _init        */
            putbyte(76,fl_resolved,0);
            putword(i,flags,lab);
            setlabel("_base",pc_begin,fl_resolved|fl_variable);
            setglobal("_base");

#else
            /* LNG .header creator */

			/* unused (magic) */
		    header[0]=0xff;
		    header[1]=0xfe;
            /* header info (version) */
		    header[2]=0x00;
		    header[3]=0x14;
			/* will be patched by lld */
		    header[4]=0x00;
		    header[5]=0x00;

            /* write header */

            i=2;while (i<6) {
              putbyte(header[i],fl_resolved,0);
              i=i+1;
		    }

#endif
            continue; }

		/*
		  start .buf directive
		*/

          if (line[i]=='b' && line[i+1]=='u') {

            /* assume .buf */

            if (lunix_mode && data_flag==0) warning(".buf in code-area");
            j=nextchar(j);
            j=getexpr(j,&ltmp,&flags,&lab);
	    if (flags&(fl_variable|fl_external|fl_extdep))
	      error("non constant argument");
	    if (ltmp>0xffff) error("word out of range");
            buf_bytes=buf_bytes+ltmp; /* delayed insertion, because we don't
                                         need buf-bytes at the very end. */
            pc=pc+ltmp;
            continue; }

          if (line[i]=='d') {

            /* assume .data */
_do_data:
            if (data_flag!=0) continue;
            data_flag=1;
            dseg_count=dseg_count+1;
            sprintf(str,"__d%i",dseg_count);
            i=getlabel(str);
            flags=0; lab=0;
            if (i!=NO_LABEL) {
              par=label_val[i];
              flags=label_stat[i];
              if (flags&fl_external) error(".data without .code"); }
            else par=0;
            writebef( 12, 2, par, flags, lab);
            continue; }

          if (line[i]=='c') {
            
            /* assume .code */

            if (data_flag==0) continue;
            if (data_flag==2) error("code after .endofcode");
            data_flag=0;
            sprintf(str,"__d%i",dseg_count);
            setlabel( str,pc,fl_resolved|fl_variable);
            continue; }

          if (line[i]=='e') {

            /* assume .endofcode */
 
            if (object_mode) goto _do_data;
	    /* library calls will be appended to this file, so
	       .endofcode would be a big mistake */
            if (data_flag==1) {
              sprintf(str,"__d%i",dseg_count);
              setlabel( str,pc,fl_resolved|fl_variable); }
            putbyte(2,fl_resolved,0);
            data_flag=2; 
            continue; }
	  
	  if (line[i]=='l') {
	    if (line[i+1]=='i') {
	      
	      /* assume .line */
	      
	      /* Only allowed in pre-processed code */
	      if (!pre_proccess)
		{
		  switch(dot_line_count)
		    {
		    case 0: warning(".line in non-preproccessed code"); 
		      break;
		    case 1: 
		      warning("futher .lines found - supressing warning");
		      break;
		    }
		  dot_line_count++;
		}
	      /* Read line # and source file name */
	      j=nextchar(j);
	      pre_line=atoi(&line[j]);       /* source line */
	      j=nextsep(j);
	      if (pre_proccess)
		strcpy(pre_pedigree,&line[j+1]); /* file list */
	      /* skip rest of line */
	      while(line[j]==',')
		j=nextsep(j+1);
	      continue; }
	    
	    if (line[i+1]=='o') {
	      
	      /* assume .longword */
	      
	      if (lunix_mode && data_flag==0) error("data in code-area");
	      while (1) {
		j=nextchar(j);
		j=getexpr(j,&ltmp,&flags,&lab);
		if (object_mode && (flags & (fl_variable|fl_external)))
		  error("nonconst longwords not supported by object format");
		putbyte((ltmp>>24) & 0xff,fl_resolved,0);
		putbyte((ltmp>>16) & 0xff,fl_resolved,0);
		putbyte((ltmp>>8) & 0xff,fl_resolved,0);
		putbyte(ltmp & 0xff,fl_resolved,0);
		if (line[j]!=',') break;
		j=j+1; }
	      continue; }
	  }
	  
          if (line[i]=='n') {
	    
            /* assume .newpage */
	    
            if (lunix_mode && data_flag==0) error(".newpage in code-area");
            if (object_mode) warning(".newpage might not work in objectmode");
            i=(pc & 255);
            if (i!=0) i=256-i;
            if (final_pass && !quiet_mode) 
              printf(" note: %i unused bytes because of .newpage\n",i);
            buf_bytes=buf_bytes+i;
            pc=pc+i;
            continue; }
	  
          if ((line[i+0]=='t')&&(line[i+1]=='e')&&
	      (line[i+2]=='x')&&(line[i+3]=='t')) {
	    /* .text                                        */
	    /* May include combination of bytes and strings */
	    
	    if (lunix_mode && data_flag==0) 
	      error("data in code-area");
	    
	    while(1) {
	      j=nextchar(j);
	      switch(line[j]) {
	      case '\"': { /* string" */
		j++;
		while (1) {
		  if (line[j]=='\"') {            /*"*/
		    j++;
		    break; }
		  if (line[j]=='\0') {
		    error("unterminated string");
		    break; }
		  j=getascii(j,&par,0); /* no ascii-petscii conversion */
		  putbyte(par,fl_resolved,0); }
		break; }
	      
	      default: /* expression */
		j=getexpr(j,&ltmp,&flags,&lab);
		if (ltmp>0xffff) error("byte out of range");
		if (object_mode && flags&(fl_variable|fl_extdep)) {
		  if (!(flags&(fl_takelo|fl_takehi))) {
		    error("byte out of range"); } }
		else if (ltmp>255) error("byte out of range");
		putbyte(ltmp,flags,lab);
		break;
	      }
	      /* to the next field */
	      j=nextchar(j);
	      if (line[j]!=',') break;
	      j++; }
	    
	    continue; }
	  
          if (line[i]=='g') {
	    
            /* assume .global */
            j=nextchar(j);
            if (is_sep(line[j])) {
              error("syntax error");
              continue; }
	    
            while (1) {
              q=nextsep(j);
              tmp=line[q];
              line[q]='\0';
              setglobal(&line[j]);
              line[q]=tmp;
              j=nextchar(q);
              if (line[j]=='\0') break;
              if (line[j]==';')  break;
              if (line[j]!=',') {
                error("syntax error");
                break; }
              j=nextchar(j+1); }
            continue; }
	  
	}
	
        if (line[j-1]==':') {
          /* label: */
         line[j-1]='\0';
         setlabel(&line[i],pc,fl_resolved|fl_variable);
         continue; }

        if (j-i==1) {
          /* one char prefix */
          if (line[i]=='+') {
            sprintf(str,"_+%i",fmark);
            fmark=fmark+1;
            setlabel(str,pc,fl_resolved|fl_variable); }
          else if (line[i]=='-') {
            sprintf(str,"_-%i",rmark);
            rmark=rmark+1;
            setlabel(str,pc,fl_resolved|fl_variable); }
          else error("syntax error");
          continue; }

        if (j-i==3) {  

          p=  (line[i]&31)*10  \
            + (line[i+1]&31)*5 \
            + (line[i+2]&31)*2 - 36;

          if (p>=0 && p<323) {
            p=hashtab[p];
            if (p==255) p=-1; }
          else p=-1;

          if (p>=0 && beflst[p][0]==line[i]   &&
              beflst[p][1]==line[i+1] &&
              beflst[p][2]==line[i+2]   ) {

            /* found assembler command */
            j=getasspar(j,&mode,&par,&flags,&lab); 
            /* find perfect match */
            q=p;
            tmp=BEF_NUM;
            while (beflst[q][0]==line[i]   &&
                   beflst[q][1]==line[i+1] &&
                   beflst[q][2]==line[i+2]   ) {
              if (mode==befatp[q]) tmp=q;
              if (mode>=5 && mode<=7 && mode-3==befatp[q]) tmp=q;
              if (befatp[q]==10) if (mode==2 || mode==5) tmp=q; 
              q=q+1;
              if (q==BEF_NUM) break; }
            if (tmp==BEF_NUM) {
              error("addressing mode not supported");
              continue; }
            else {
              writebef(befopc[tmp],befatp[tmp],par,flags,lab);
              continue; }
          }
	  
          /* unknown command with 3 letters */
	  if (line[i]=='o' && line[i+1]=='r' && line[i+2]=='g' ) {
	    /* org-command */
	    unsigned long ltmp;
	    j=nextchar(j);
	    j=getexpr(j,&ltmp,&flags,&lab);
	    if (ltmp>0xffff) error("org out of range");
            if (!object_mode) pc=ltmp; 
            else { 
              pc=0;
              if (final_pass) warning("org will be ignored (object-mode)"); }
            if (org_lock) error("nested org");
            continue; }
        }
	/* no such command (assume it a label?) */ 
	tmp=nextchar(j);
	line[j]='\0';
	if (line[tmp]=='e' && line[tmp+1]=='q' && line[tmp+2]=='u') {
	  /* label equ expression */
	  unsigned long ltmp;
	  j=nextchar(nextsep(tmp));
	  j=getexpr(j,&ltmp,&flags,&lab);
	  setlabel(&line[i],ltmp,flags);
	  continue; }
	
	{
	  char message[1024];
	  line[j]=0;
	  sprintf(message,"unknown command `%s'",&line[i]);
	  error(message);        
	}
      }
    }
    
    /* pass done */
    
  fclose(infile);
   if (lunix_mode && data_flag!=2)
     if (!object_mode) error("missing .endofcode directive");

  if (object_mode && data_flag==1) {
      /* add .code to end of file */
      data_flag=0;
      sprintf(str,"__d%i",dseg_count);
      setlabel( str,pc,fl_resolved|fl_variable); }

  pc_end=pc;
  if ((pc_end!=pc || labresolved_flag) && final_pass) {
    if (!quiet_mode) printf("  sorry, need another pass\n");
    fclose(binfile);
    final_pass=0; }

  if (errors!=0) {
    printf("%i Error",errors);
    unlink(file_output);
    if (errors>1) printf("s");
    printf(", stopped after pass %i\n",pass);
    exit(1); }
  }
  while (!final_pass);

  if (buf_bytes!=0) {
    if (object_mode) {
      i=0;
      while (i<buf_bytes) {
        plain_buf[plain_buf_len++]=0;
        if (plain_buf_len==127) cleanup_plain_buf();
        i=i+1; }
      }
    else if (!quiet_mode)
      printf(" note: last %i buffer-bytes not saved in image\n",buf_bytes);
    }

  if (object_mode) {
    cleanup_plain_buf();
    raw_put(0); }
  
  fclose(binfile);

  /* delete lupo output */
  if (pre_proccess) unlink(pre_file);

  /* optional: writing of labellist */
  if (file_labels!=NULL) {
    binfile=fopen(file_labels,"w");
    i=0;
    while (i<labels) {
      if ( (label_stat[i]&fl_global)!=0 ) 
        fprintf(binfile,"%s \tequ %i\n",&label_tab[label_pos[i]],label_val[i]);
      i=i+1; }
    fclose(binfile); }

  /* call linker to postproccess file if needed */
  if (use_linker) {
    char temp[1024];
    sprintf(temp,"lld -q -o %s %s", file_output, tmpobj_file);
    if (!quiet_mode)
      printf("calling lld to post-proccess file\n");
    if(system(temp)) {
      printf("%s: lld returned with error, no output created\n",argv[0]);
      unlink(tmpobj_file);
      exit(1); }
      unlink(tmpobj_file);
    exit(0); }

  /* all done */                    
  if (!quiet_mode) {
    printf("done, %i labels, %i bytes labelspace, %i bytes of code",labels,label_tab_pos,pc_end-pc_begin);
    if (lunix_mode) printf(" (LUnix)");
    if (object_mode) printf("\n(%i bytes objectcode)",code_length);
    printf("\n"); }

  exit(0);
}
