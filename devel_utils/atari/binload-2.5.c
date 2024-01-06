/************************************************************************/
/* binload.c                                                            */
/* Atari binary load format file analyzer                               */
/* Preston Crow                                                         */
/* crow@cs.dartmouth.edu                                                */
/*                                                                      */
/* Public Domain                                                        */
/*                                                                      */
/* Version History                                                      */
/*  2 Jun 95  Version 1.0   Preston Crow <crow@cs.dartmouth.edu>        */
/*            Initial public release                                    */
/*  4 Jun 95  Version 2.0   Preston Crow <crow@cs.dartmouth.edu>        */
/*            Create fixed version of the file                          */
/*  7 Jun 95  Version 2.1   Preston Crow <crow@cs.dartmouth.edu>        */
/*            Use separate functions                                    */
/*            Merge overlapping and adjacent blocks                     */
/*  9 Jun 95  Version 2.2   Chad Wagner <cmwagner@gate.net>             */
/*            Ported to MS-DOS machines, should compile and work under  */
/*            MS-DOS, *** compile in COMPACT model. ***                 */
/* 11 Nov 95  Version 2.3   Chad Wagner <cmwagner@gate.net>             */
/*            Added d switch, which allow disassembly of blocks to      */
/*            stdout                                                    */
/*            disassemble_block() function added                        */
/*            outins() function added                                   */
/*            instable[] added                                          */
/* 16 Nov 95  Version 2.4   Chad Wagner <cmwagner@gate.net>             */
/*            Fixed bogus operands on output when operands extend       */
/*            beyond end of block, just puts out a bogus instruction    */
/*            symbol now (???).                                         */
/* 19 Feb 98  Version 2.5   Preston Crow <crow@cs.dartmouth.edu>	*/
/*	      Add warning for DOS-overwriting files.			*/
/*	      Add warning for blocks that contain calls to direct	*/
/*	      sector I/O; disabled due to high frequency of such code	*/
/*	      existing dormant within cracked files from unused code.	*/
/*									*/
/*									*/
/* To-do:								*/
/*									*/
/*	Extended DOS-overwriting warning--one warning per incident,	*/
/*	but list which versions are at risk.  Also narrow down the	*/
/*	addresses that actually matter.					*/
/*									*/
/*	Redo the command line options--options to control which		*/
/*	warnings are active, an option to turn on file cleanup,		*/
/*	an option to control block merging and out-of-order/non-	*/
/*	sequential block merging, maybe others.				*/
/*									*/
/*	Add block decompression--detect when there are blocks close	*/
/*	together that could be combined by filling in zeros between	*/
/*	them.  It seems that someone wrote a simple compression		*/
/*	program that looks for strings of 5 or more zeros and split	*/
/*	blocks up instead of including them.  Regions of files		*/
/*	containing graphics data have lots of such blocks.		*/
/*									*/
/*	Add block compression--if we can add in the zeros, we sure	*/
/*	should be able to take them out.				*/
/*									*/
/*	Add a file compare feature.  It would load two files into	*/
/*	separate 64K buffers, and then report the number of bytes	*/
/*	that differ (and optionally display a list of those addresses).	*/
/*									*/
/*	Other ideas???							*/
/*									*/
/*	Future command line options:					*/
/*	      -d	enable disassembly				*/
/*	      -c	compare two binary load files			*/
/*	      -Wall	enable all warnings				*/
/*	      -Wdos	warn if it will overwrite DOS			*/
/*	      -Wrun	warn if more than one run address		*/
/*	      -Wio	warn if direct sector I/O routine is detected	*/
/*	      -Woverlap	warn if blocks overlap				*/
/*	      -f	fix up (write output file)			*/
/*	      -m	merge blocks aggressively (even if		*/
/*			non-sequential)					*/
/*	      -u	uncompress--merge blocks that are less than	*/
/*			126 bytes apart, filling with zeros		*/
/*	      -u#	uncompress blocks less than # bytes apart	*/
/*	      -z	zero-compress, splitting blocks when five or	*/
/*			more zeros in a row are found			*/
/*		Note:  options -m, -u, and -z only have meaning if -f	*/
/*		is specified; -c and -f can not be used together.	*/
/*									*/
/************************************************************************/

#if defined(__MSDOS) || defined(__MSDOS__) || defined(_MSDOS) || \
    defined(_MSDOS_)
#define MSDOS
#endif

/************************************************************************/
/* Include files                                                        */
/************************************************************************/
#include <stdio.h>
#include <stdlib.h>

#ifdef MSDOS
#include <alloc.h>
#else
#include <malloc.h>
#endif

/************************************************************************/
/* Constants and Macros                                                 */
/************************************************************************/
#define USAGE "Binload version 2.4\nAtari binary load file analysis and repair\nUsage:  binload [-d] sourcefile [destfile]\n"
#ifndef SEEK_SET /* should be in <stdio.h>, but some systems are lame */
#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2
#endif

/************************************************************************/
/* Data types                                                           */
/************************************************************************/
struct block {
   struct block *next;
   unsigned int start;
   unsigned int end;
};

struct {
   char   *instruct;
   int   length;
   int   branch;
} instable[] = {
   { "BRK",               0, 0 },
   { "ORA\t($*,X)",       1, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "ORA\t$*",           1, 0 },
   { "ASL\t$*",           1, 0 },
   { "???",               0, 0 },
   { "PHP",               0, 0 },
   { "ORA\t#$*",          1, 0 },
   { "ASL",               0, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "ORA\t$*",           2, 0 },
   { "ASL\t$*",           2, 0 },
   { "???",               0, 0 },
   { "BPL\t$*",           1, 1 },
   { "ORA\t($*),Y",       1, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "ORA\t$*,X",         1, 0 },
   { "ASL\t$*,X",         1, 0 },
   { "???",               0, 0 },
   { "CLC",               0, 0 },
   { "ORA\t$*,Y",         2, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "ORA\t$*,X",         2, 0 },
   { "ASL\t$*,X",         2, 0 },
   { "???",               0, 0 },
   { "JSR\t$*",           2, 0 },
   { "AND\t($*,X)",       1, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "BIT\t$*",           1, 0 },
   { "AND\t$*",           1, 0 },
   { "ROL\t$*",           1, 0 },
   { "???",               0, 0 },
   { "PLP",               0, 0 },
   { "AND\t#$*",          1, 0 },
   { "ROL",               0, 0 },
   { "???",               0, 0 },
   { "BIT\t$*",           2, 0 },
   { "AND\t$*",           2, 0 },
   { "ROL\t$*",           2, 0 },
   { "???",               0, 0 },
   { "BMI\t$*",           1, 1 },
   { "AND\t($*),Y",       1, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "AND\t$*,X",         1, 0 },
   { "ROL\t$*,X",         1, 0 },
   { "???",               0, 0 },
   { "SEC",               0, 0 },
   { "AND\t$*,Y",         2, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "AND\t$*,X",         2, 0 },
   { "ROL\t$*,X",         2, 0 },
   { "???",               0, 0 },
   { "RTI",               0, 0 },
   { "EOR\t($*,X)",       1, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "EOR\t$*",           1, 0 },
   { "LSR\t$*",           1, 0 },
   { "???",               0, 0 },
   { "PHA",               0, 0 },
   { "EOR\t#$*",          1, 0 },
   { "LSR",               0, 0 },
   { "???",               0, 0 },
   { "JMP\t$*",           2, 0 },
   { "EOR\t$*",           2, 0 },
   { "LSR\t$*",           2, 0 },
   { "???",               0, 0 },
   { "BVC\t$*",           1, 1 },
   { "EOR\t($*),Y",       1, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "EOR\t$*,X",         1, 0 },
   { "LSR\t$*,X",         1, 0 },
   { "???",               0, 0 },
   { "CLI",               0, 0 },
   { "EOR\t$*,Y",         2, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "EOR\t$*,X",         2, 0 },
   { "LSR\t$*,X",         2, 0 },
   { "???",               0, 0 },
   { "RTS",               0, 0 },
   { "ADC\t($*,X)",       1, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "ADC\t$*",           1, 0 },
   { "ROR\t$*",           1, 0 },
   { "???",               0, 0 },
   { "PLA",               0, 0 },
   { "ADC\t#$*",          1, 0 },
   { "ROR",               0, 0 },
   { "???",               0, 0 },
   { "JMP\t($*)",         2, 0 },
   { "ADC\t$*",           2, 0 },
   { "ROR\t$*",           2, 0 },
   { "???",               0, 0 },
   { "BVS\t$*",           1, 1 },
   { "ADC\t($*),Y",       1, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "ADC\t$*,X",         1, 0 },
   { "ROR\t$*,X",         1, 0 },
   { "???",               0, 0 },
   { "SEI",               0, 0 },
   { "ADC\t$*,Y",         2, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "ADC\t$*,X",         2, 0 },
   { "ROR\t$*,X",         2, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "STA\t($*,X)",       1, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "STY\t$*",           1, 0 },
   { "STA\t$*",           1, 0 },
   { "STX\t$*",           1, 0 },
   { "???",               0, 0 },
   { "DEY",               0, 0 },
   { "???",               0, 0 },
   { "TXA",               0, 0 },
   { "???",               0, 0 },
   { "STY\t$*",           2, 0 },
   { "STA\t$*",           2, 0 },
   { "STX\t$*",           2, 0 },
   { "???",               0, 0 },
   { "BCC\t$*",           1, 1 },
   { "STA\t($*),Y",       1, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "STY\t$*,X",         1, 0 },
   { "STA\t$*,X",         1, 0 },
   { "STX\t$*,Y",         1, 0 },
   { "???",               0, 0 },
   { "TYA",               0, 0 },
   { "STA\t$*,Y",         2, 0 },
   { "TXS",               0, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "STA\t$*,X",         2, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "LDY\t#$*",          1, 0 },
   { "LDA\t($*,X)",       1, 0 },
   { "LDX\t#$*",          1, 0 },
   { "???",               0, 0 },
   { "LDY\t$*",           1, 0 },
   { "LDA\t$*",           1, 0 },
   { "LDX\t$*",           1, 0 },
   { "???",               0, 0 },
   { "TAY",               0, 0 },
   { "LDA\t#$*",          1, 0 },
   { "TAX",               0, 0 },
   { "???",               0, 0 },
   { "LDY\t$*",           2, 0 },
   { "LDA\t$*",           2, 0 },
   { "LDX\t$*",           2, 0 },
   { "???",               0, 0 },
   { "BCS\t$*",           1, 1 },
   { "LDA\t($*),Y",       1, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "LDY\t$*,X",         1, 0 },
   { "LDA\t$*,X",         1, 0 },
   { "LDX\t$*,Y",         1, 0 },
   { "???",               0, 0 },
   { "CLV",               0, 0 },
   { "LDA\t$*,Y",         2, 0 },
   { "TSX",               0, 0 },
   { "???",               0, 0 },
   { "LDY\t$*,X",         2, 0 },
   { "LDA\t$*,X",         2, 0 },
   { "LDX\t$*,Y",         2, 0 },
   { "???",               0, 0 },
   { "CPY\t#$*",          1, 0 },
   { "CMP\t($*,X)",       1, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "CPY\t$*",           1, 0 },
   { "CMP\t$*",           1, 0 },
   { "DEC\t$*",           1, 0 },
   { "???",               0, 0 },
   { "INY",               0, 0 },
   { "CMP\t#$*",          1, 0 },
   { "DEX",               0, 0 },
   { "???",               0, 0 },
   { "CPY\t$*",           2, 0 },
   { "CMP\t$*",           2, 0 },
   { "DEC\t$*",           2, 0 },
   { "???",               0, 0 },
   { "BNE\t$*",           1, 1 },
   { "CMP\t($*),Y",       1, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "CMP\t$*,X",         1, 0 },
   { "DEC\t$*,X",         1, 0 },
   { "???",               0, 0 },
   { "CLD",               0, 0 },
   { "CMP\t$*,Y",         2, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "CMP\t$*,X",         2, 0 },
   { "DEC\t$*,X",         2, 0 },
   { "???",               0, 0 },
   { "CPX\t#$*",          1, 0 },
   { "SBC\t($*,X)",       1, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "CPX\t$*",           1, 0 },
   { "SBC\t$*",           1, 0 },
   { "INC\t$*",           1, 0 },
   { "???",               0, 0 },
   { "INX",               0, 0 },
   { "SBC\t#$*",          1, 0 },
   { "NOP",               0, 0 },
   { "???",               0, 0 },
   { "CPX\t$*",           2, 0 },
   { "SBC\t$*",           2, 0 },
   { "INC\t$*",           2, 0 },
   { "???",               0, 0 },
   { "BEQ\t$*",           1, 1 },
   { "SBC\t($*),Y",       1, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "SBC\t$*,X",         1, 0 },
   { "INC\t$*,X",         1, 0 },
   { "???",               0, 0 },
   { "SED",               0, 0 },
   { "SBC\t$*,Y",         2, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "???",               0, 0 },
   { "SBC\t$*,X",         2, 0 },
   { "INC\t$*,X",         2, 0 },
   { "???",               0, 0 },
   { "\0",                0, 0 }
};

/************************************************************************/
/* Function prototypes                                                  */
/************************************************************************/
int read_block(FILE *fin,FILE *fout,char *name);
void insert_block(unsigned int start,unsigned int end);
void write_blocks(FILE *fout);
void disassemble_block(unsigned int start,unsigned int end);
void outins(unsigned int program_counter,unsigned int ins,unsigned int end);

/************************************************************************/
/* Global variables                                                     */
/************************************************************************/
struct block *blocks=NULL;
unsigned char *data; /* The full address space */
int run=0; /* True if load address specified */
long flen; /* Length of the file */
int dis=0; /* True if disassembly requested */

/************************************************************************/
/* main()                                                               */
/************************************************************************/
int main (int argc,char *argv[])
{
   FILE *fin,*fout;
   int c1,c2;

   --argc;++argv;
   /* Process switches */
   if (argc) while (*argv[0]=='-') {
      int nomore=0;

      ++argv[0]; /* skip the '-' */
      while(*argv[0]) {
         switch(*argv[0]) {
               case '-':
                  nomore=1;
                  break;
               case 'd':
               case 'D':
                  dis = !dis;
                  break;
               default:
                  fprintf(stderr,"Unsupported switch:  %c\n\n%s",*argv[0],
                    USAGE);
                  exit(1);
         }
         ++argv[0]; /* We've processed this flag */
      }
      --argc;++argv; /* Done processing these flags */
      if(nomore) break; /* Filename may begin with '-' */
   }

   if (!argc || argc>2) {
      fprintf(stderr,USAGE);
      exit(1);
   }

#ifdef MSDOS
   data = farmalloc(65536L);
#else
   data = malloc(65536L);
#endif
   if (!data) {
      fprintf(stderr,"Unable to allocate memory for address space.\n");
      exit(1);
   }
   fin=fopen(*argv,"rb");
   if (!fin) {
      fprintf(stderr,"%s:  Unable to open file\n\n%s",*argv,USAGE);
      exit(1);
   }
   c1=getc(fin);
   c2=getc(fin);
   if (c1 != c2 || c1 != 0xff) {
      printf("%s: Not an Atari 8-bit binary load format file\n",*argv);
      fclose(fin);
      exit(1);
   }
   printf("Binary file:  %s\n",*argv);

   fout=NULL;
   if (argc>1) {
      fout=fopen(argv[1],"wb");
      if (!fout) {
         fprintf(stderr,"%s:  Unable to open file\n\n%s",*argv,USAGE);
         exit(1);
      }
   }

   if (fout) { fputc(0xff,fout);fputc(0xff,fout); }

   fseek(fin,0,SEEK_END);
   flen=ftell(fin);
   fseek(fin,2,SEEK_SET);
   while (ftell(fin)<flen) {
      if (read_block(fin,fout,*argv)) break;
   }
   fclose(fin);
   if (run) insert_block(0x02e0,0x02e1);
   write_blocks(fout); /* Write all blocks since last init */
   if (fout) fclose(fout);
   return(0);
}

/************************************************************************/
/* read_block()                                                         */
/************************************************************************/
int read_block(FILE *fin,FILE *fout,char *name)
{
   unsigned int start;
   unsigned int end;
   unsigned int length;
   int c1,c2;

   do {
      c1=fgetc(fin);
      c2=fgetc(fin);
      start=c2*256+c1;
      if (start == 0xffff) {
         printf("%s:  Unexpected second 0xffff format header\n",name);
      }
   } while (start == 0xffff);
   if (feof(fin)) {
      printf("%s:  Unexpected end of file in load range start address\n",name);
      return(1);
   }
   c1=fgetc(fin);
   c2=fgetc(fin);
   end=c2*256+c1;
   length=end-start+1;
   if (feof(fin)) {
      printf("%s:  Unexpected end of file in load range end address\n",name);
      return(1);
   }
   if (start==end && c1==c2) {
      printf("%s:  Apparent garbage fill at end of file (%ld bytes)\n",name,flen-ftell(fin)+4);
      return(1);
   }
   if (end<start) {
      printf("%s:  Start:  %u\tEnd:  %u\tLength  %u\n",name,start,end,length);
      printf("%s:  Error:  %ld bytes in file after invalid load range\n",name,flen-ftell(fin));
      return(1);
   }
   if (flen<ftell(fin)+length) {
      printf("%s:  Start:  %u\tEnd:  %u\tLength  %u\n",name,start,end,length);
      printf("\t\tTruncated file:  missing data in load block (%ld bytes missing)\n",ftell(fin)+length-flen);
      return(1);
   }

   /* Read in the data for this block */
   fread(&data[start],length,1,fin);

   /* Check for run address */
   if (start<=0x02e1 && start+length>=0x02e0) {
      if (start==0x02e1 || start+length==0x02e0) {
         printf("%s:  Warning:  Partial run address\n",name);
      }
      if (run) printf("%s:  Unexpected second run address\n",name);
      run=1;
      printf("%s:  Run at:  %u\n",name,data[0x02e0]+256*data[0x02e1]);
      if (start>=0x02e0 && end<=0x02e1) return(0);
      /* Other data in this block */
      if (start==0x02e0 || start==0x02e1) {
         /* Run and init in the same block--split */
         start=0x02e2;
         length=end-start+1;
      }
      else if (end==0x02e0 || end==0x02e1) {
         /* other stuff before the run address--split */
         end=0x02df;
         length=end-start+1;
      }
      else {
         /* Run address in the middle of the block */
         printf("%s:  Start:  %u\tEnd:  %u\tLength  %u\n",name,start,0x02df,0x02df-start+1);
         insert_block(start,0x02df);
         start=0x02e2;
         length=end-start+1;
      }
   }

   /* Check for init address */
   /* We know there's nothing before the address in the block, */
   /* as we would have split it off above as a run address.    */
   if (start<=0x02e3 && start+length>=0x02e2) {
      if (start==0x02e3 || start+length==0x02e2) {
         printf("%s:  Warning:  Partial init address\n",name);
      }
      printf("%s:  Init at:  %u\n",name,data[0x02e2]+256*data[0x02e3]);
      /* Other data in this block? */
      if (end > 0x02e3) {
         /* More stuff past init--split */
         printf("%s:  Start:  %u\tEnd:  %u\tLength  %u\n",name,0x02e4,end,length);
         insert_block(0x02e4,end);
         end=0x02e3;
         length=end-start+1;
      }
      insert_block(start,end);
      if (dis) disassemble_block(start,end);
      /* Write everything out to avoid cross-init merges */
      write_blocks(fout);
      return(0);
   }

   /* Print data block load message */
   printf("%s:  Start:  %u\tEnd:  %u\tLength  %u\n",name,start,end,length);

   /* Warn if it overwrites DOS */
   /*
    * It would be nice to have an exact list of the addresses each version
    * of DOS uses for code and buffers.
    * For now, we'll just assume that page 7 through MEMLO is used.
    *
    *	Version		DUP.SYS high	MEMLO
    *	DOS 2.5		$3005		$1E7C
    *	DOS 2.0S	$3305		$1F7C
    *	MyDOS4.5	$4376		$1EE8
    *	SmartDOS 6.1D	$411D		$1E18
    *	SpDOS 32d	none		$1819
    *	SpDOSX		none		$1645
    *	(SpartaDos may use some high memory, too.)
    *
    * For now, it just warns based on DOS2.0S MEMLO.
    *
    * It shouldn't be too hard to take a simple working binload program
    * and prepend it with a garbage block to clobber memory and see if
    * it still loads.  It would need to be a program that uses both init
    * and run, and one with both large and small blocks so that all relevant
    * code paths within DOS will be tested.
    */
   if (end>=1536+256 && start <=0x1f7c /* 8051 */) {
	   printf("%s:  Warning:  Block may overwrite area used by DOS\n",name);
   }

#if 0
   /* Warn of direct sector I/O */
   /*
    * This is currently disabled.
    *
    * It seems that a lot of cracked programs, while they don't do direct
    * sector I/O anymore, their original loader code is still there, causing
    * too many false alarms for this to be useful.
    *
    * The idea was to detect games that might clobber other files by saving
    * high scores and such.
    *
    * For now, you can get the same thing by disassembling and grepping the
    * output for:  JSR $E453
    *
    */
   if (length>2) {
	   int i;
	   for (i=0;i<length-3;++i) {
		   /* if (data[start+i]=='JSR $E453') */
		   if (data[start+i]==32 && data[start+i+1]==0x53 && (data[start+i+2]==0xE4)) {
			   printf("%s:  Warning:  Direct sector I/O\n",name);
		   }
	   }
   }
#endif

   insert_block(start,end);
   if (dis) disassemble_block(start,end);

   return(0);
}

/************************************************************************/
/* insert_block()                                                       */
/************************************************************************/
void insert_block(unsigned int start,unsigned int end)
{
   struct block *b,*bp;

   bp=NULL; /* previous block */
   b=blocks;
   while(b) {
      /* Check for merge */
      if (b->end+1 == start) {
         printf("\t\tBlock merges with a previous block\n");
         b->end=end;
         return;
      }
      if (b->start-1 == end) {
         printf("\t\tBlock merges with a previous block (unexpected ordering)\n");
         b->start=start;
         return;
      }
      /* Check for overlap */
      if (b->start <= start && end <= b->end) {
         printf("\t\tWarning:  Completely overlaps a previous block--merged\n");
         return;
      }
      if (b->start <= end && b->start >= start) {
         b->start=start;
         if (b->end<end) b->end=end;
         printf("\t\tWarning:  Partially overlaps a previous block--merged\n");
         return;
      }
      if (b->end <= end && b->end >= start) {
         b->end=end;
         if (b->start>start) b->start=start;
         printf("\t\tWarning:  Partially overlaps a previous block--merged\n");
         return;
      }
      bp=b;
      b=b->next;
   }
   /* Add this block to the end of the list */
   b=malloc(sizeof(*b));
   if(!b) {
      fprintf(stderr,"Unable to malloc memory--aborted\n");
   }
   b->start=start;
   b->end=end;
   b->next=NULL;
   if (bp) bp->next=b;
   else blocks=b;
}

/************************************************************************/
/* write_blocks()                                                       */
/************************************************************************/
void write_blocks(FILE *fout)
{
   struct block *b,*bp;

   b=blocks;
   while (b) {
      if (fout) {
         fputc(b->start&0xff,fout);
         fputc(b->start/0x100,fout);
         fputc(b->end&0xff,fout);
         fputc(b->end/0x100,fout);
         fwrite(&data[b->start],(b->end - b->start + 1),1,fout);
      }
      bp=b; /* To allow free call after last use */
      b=b->next;
      free(bp);
   }
   blocks=NULL;
}

/************************************************************************/
/* disassemble_block()                                                  */
/************************************************************************/
void disassemble_block(unsigned int start,unsigned int end)
{
unsigned   int   a,program_counter = start,inslen=0,ins=0;

   while (program_counter <= end) {
      ins = data[program_counter];
      inslen = instable[ins].length;
		printf("%04X ",program_counter);

		if (program_counter + inslen > end)
			inslen = end - program_counter;

		for (a=0; a<=inslen; a++) {
			printf("%02X ",(unsigned int)data[program_counter + a]);
		}
		for (a=0; a<(3-inslen); a++) {
				printf("   ");
		}
		outins(program_counter,ins,end);
      program_counter += (inslen + 1);
   }
}

void outins(unsigned int program_counter,unsigned int ins,unsigned int end)
{
char obuf[256],*p;
signed char uPdata;

   strcpy(obuf,instable[ins].instruct);
   for (p=obuf; *p; p++) {
      if (*p == '*') {
         *p = '\0';
         p++;
         break;
      }
   }

   if (instable[data[program_counter]].length == 0) {
      printf("%s\n",instable[data[program_counter]].instruct);
	} else if (instable[data[program_counter]].length) {
		if (program_counter + instable[data[program_counter]].length > end) {
			printf("???\n");
			return;
		}
      printf("%s",obuf);
      if (instable[ins].branch) {
         uPdata = (signed int)data[program_counter + 1];
         printf("%04X",program_counter+2+(signed int)uPdata);
      } else {
         if (instable[ins].length == 1) {
            printf("%02X",(unsigned char)data[program_counter + 1]);
         } else if (instable[ins].length == 2) {
            printf("%04X",(unsigned int)data[program_counter + 1] |
              (unsigned int)(data[program_counter + 2] << 8));
         }
      }
      printf("%s\n",p);
   }
}
