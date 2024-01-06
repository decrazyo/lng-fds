/************************************************************************/
/* atr2unix.c                                                           */
/*                                                                      */
/* Preston Crow                                                         */
/* Public Domain                                                        */
/*                                                                      */
/* Extract files from an Atari DOS or MyDOS .ATR file                   */
/*                                                                      */
/* Version History                                                      */
/*  5 Jun 95  Version 1.0   Preston Crow <crow@cs.dartmouth.edu>        */
/*	      Initial public release                                    */
/* 20 Dec 95  Version 1.1   Chad Wagner <cmwagner@gate.net>             */
/*	      Ported to MS-DOS machines					*/
/* 10 Feb 98  Version 1.2   Preston Crow <crow@cs.dartmouth.edu>	*/
/*	      Expanded 256-byte sector support				*/
/************************************************************************/

/************************************************************************/
/* Portability macros                                                   */
/* 1  Jun 95  crow@cs.dartmouth.edu (Preston Crow)                      */
/************************************************************************/
#if defined(__MSDOS) || defined(__MSDOS__) || defined(_MSDOS) || \
	 defined(_MSDOS_)
#define MSDOS /* icky, icky, icky! */
#endif

/************************************************************************/
/* Include files                                                        */
/************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/stat.h>

#ifdef MSDOS
#include <dir.h>
#include <io.h>
#else
#include <unistd.h>
#endif

/************************************************************************/
/* Macros and Constants                                                 */
/************************************************************************/
#define ATRHEAD 16
#define USAGE "atr2unix [-dlm-] atarifile.atr\n    Flags:\n\t-l Convert f" \
"ilenames to lower case\n\t-m MyDOS format disk image\n\t-- Next argument" \
" is not a flag\n\t-d debugging\n"

#ifndef SEEK_SET
#define SEEK_SET 0 /* May be missing from stdio.h */
#endif
#define SEEK(n)		(ddshortinit?SEEK1(n):SEEK2(n))
#define SEEK1(n)	(ATRHEAD + ((n<4)?((n-1)*128):(3*128+(n-4)*secsize)))
#define SEEK2(n)	(ATRHEAD + ((n-1)*secsize))

/************************************************************************/
/* Data types                                                           */
/************************************************************************/
struct atari_dirent {
	unsigned char flag; /* set bits:  7->deleted  6->in use  5->locked  0->write open */
	unsigned char countlo; /* Number of sectors in file */
	unsigned char counthi;
	unsigned char startlo; /* First sector in file */
	unsigned char starthi;
	char namelo[8];
	char namehi[3];
};

/************************************************************************/
/* Function Prototypes                                                  */
/************************************************************************/
void read_dir(FILE *in,int sector);
void read_file(char *name,FILE *in,FILE *out,int sector,int count,int filenum);

/************************************************************************/
/* Global variables                                                     */
/************************************************************************/
int ddshortinit=0; /* True indicates double density with first 3 sectors 128 bytes */
int secsize;
int mydos=0;
int lowcase=0;
int debug=0;

/************************************************************************/
/* main()                                                               */
/* Process command line                                                 */
/* Open input .ATR file                                                 */
/* Interpret .ATR header                                                */
/************************************************************************/
int main(int argc,char *argv[])
{
	FILE *in;
	unsigned char head[16];

	--argc; ++argv; /* Skip program name */

	/* Process flags */
	while (argc) {
		int done=0;

		if (**argv=='-') {
			++*argv;
			while(**argv) {
				switch(**argv) {
				      case 'm': /* MyDos disk */
					mydos=1;
					break;
				      case '-': /* Last option */
					done=1;
					break;
				      case 'l': /* strlwr names */
					lowcase=1;
					break;
				      case 'd': /* debugging */
					debug=1;
					break;
				      default:
					fprintf(stderr,USAGE);
					exit(1);
				}
				++*argv;
			}
			--argc; ++argv;
		}
		else break;
		if (done) break;
	}

	if (!argc) {
		fprintf(stderr,USAGE);
		exit(1);
	}
	in=fopen(*argv,"rb");
	if (!in) {
		fprintf(stderr,"Unable to open %s\n%s",*argv,USAGE);
		exit(1);
	}
	--argc; ++argv;
	if (argc) {
		if (chdir(*argv)) {
			fprintf(stderr,"Unable to change to directory: %s\n%s",*argv,USAGE);
			exit(1);
		}
	}

	fread(head,ATRHEAD,1,in);
	secsize=head[4]+256*head[5];
	{
		struct stat buf;
		fstat(fileno(in),&buf);
		if (((buf.st_size-ATRHEAD)%256)==128) ddshortinit=1;
		if (debug) {
			if (ddshortinit && secsize==256) printf("DD, but first 3 sectors SD\n");
			else if (secsize==256) printf("DD, including first 3 sectors\n");
		}
	}
	read_dir(in,361);
	return(0);
}

/************************************************************************/
/* read_dir()                                                           */
/* Read the entries in a directory                                      */
/* Call read_file() for files, read_dir() for subdirectories            */
/************************************************************************/
void read_dir(FILE *in,int sector)
{
	int i,j,k;
	struct atari_dirent f;
	FILE *out;
	char name[13];

	for(i=0;i<64;++i) {
		fseek(in,(long)SEEK(sector)+i*sizeof(f)+(secsize-128)*(i/8),SEEK_SET);
		fread(&f,sizeof(f),1,in);
		if (!f.flag) return; /* No more entries */
		if (f.flag&128) continue; /* Deleted file */
		for(j=0;j<8;++j) {
			name[j]=f.namelo[j];
			if (name[j]==' ') break;
		}
		name[j]='.';
		++j;
		for(k=0;k<3;++k,++j) {
			name[j]=f.namehi[k];
			if (name[j]==' ') break;
		}
		name[j]=0;
		if (name[j-1]=='.') name[j-1]=0;
		if(lowcase) for(j=0;name[j];++j) name[j]=tolower(name[j]);

		if (f.flag ==0x47 ) { /* Seems to work */
			printf("Warning:  File %s has flag bit 1 set--file ignored\n",name);
			continue;
		}
		if (mydos && f.flag&16) { /* Subdirectory */
			if (debug) printf("subdir %s (sec %d);\n",name,f.startlo+256*f.starthi);
#ifdef MSDOS
			mkdir(name);
#else
			mkdir(name,0777);
#endif
			chdir(name);
			read_dir(in,f.startlo+256*f.starthi);
			chdir("..");
		}
		else {
			out=fopen(name,"wb");
			if (!out) {
				fprintf(stderr,"Unable to create file:  %s\n",name);
				exit(2);
			}
			if (debug) printf("readfile %s (sec %d,count %d,flags %x);\n",name,f.startlo+256*f.starthi,f.countlo+256*f.counthi,f.flag);
			read_file(name,in,out,f.startlo+256*f.starthi,f.countlo+256*f.counthi,i);
			if (f.flag&32) { /* Make locked files read-only */
#ifdef MSDOS
				chmod(name,S_IREAD);
#else
				mode_t um;

				um=umask(022);
				umask(um);
				chmod(name,0444 & ~um);
#endif
			}
		}
	}
}

/************************************************************************/
/* read_file()                                                          */
/* Trace through the sector chain.                                      */
/* Complications: Are the file numbers or high bits on the sector       */
/*		  number?                                               */
/*		  What about the last block code for 256-byte sectors?  */
/************************************************************************/
void read_file(char *name,FILE *in,FILE *out,int sector,int count,int filenum)
{
	unsigned char buf[256];

	buf[secsize-1]=0;
	while(count) {
		if (sector<1) {
			fprintf(stderr,"Corrupted file (invalid sector %d): %s\n",sector,name);
			return;
		}
		if (buf[secsize-1]&128 && secsize==128) {
			fprintf(stderr,"Corrupted file (unexpected EOF): %s\n",name);
			return;
		}
		if (fseek(in,(long)SEEK(sector),SEEK_SET)) {
			fprintf(stderr,"Corrupted file (next sector %d): %s\n",sector,name);
			return;
		}
		fread(buf,secsize,1,in);
		fwrite(buf,buf[secsize-1],1,out);
		if (mydos) {
			sector=buf[secsize-2]+buf[secsize-3]*256;
		}
		else { /* DOS 2.0 */
			sector=buf[secsize-2]+(3&buf[secsize-3])*256;
			if (buf[secsize-3]>>2 != filenum) {
				fprintf(stderr,"Corrupted file (167: file number mismatch): %s\n",name);
				return;
			}
		}
		--count;
	}
	if (!(buf[secsize-1]&128) && secsize==128 && sector) {
		fprintf(stderr,"Corrupted file (expected EOF, code %d, next sector %d): %s\n",buf[secsize-1],sector,name);
		return;
	}

	fclose(out);
}
