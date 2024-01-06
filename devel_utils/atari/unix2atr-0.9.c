/************************************************************************/
/* unix2atr.c								*/
/*									*/
/* Preston Crow								*/
/* Public Domain						       	*/
/*									*/
/* Extract files from a Unix directory tree and create a MyDOS		*/
/* ATR-format disk image file.						*/
/*									*/
/* To-do for version 1.0:						*/
/*	Eliminate any bugs						*/
/*	Fix up the DOS 2.5 boot sectors.				*/
/*	      * Adjust for DOS.SYS if it is there for DOS2.0/2.5.	*/
/*									*/
/* To-do after 1.0:							*/
/*	Support for DOS2.0D?? (256-byte sectors without MyDOS)		*/
/*	      * Is it any different from 2.0S?				*/
/*	Support for SpartaDOS						*/
/*	      * This will probably have to be coded by someone else,	*/
/*		as I'm not terribly interested in it.			*/
/*	Support for more MyDOS versions					*/
/*	      * Simply a matter of detecting the version and writing	*/
/*		out the right boot sectors.				*/
/*									*/
/* Version History							*/
/*									*/
/* 14 Mar 98  Version 0.9   Preston Crow <crow@cs.dartmouth.edu>	*/
/*									*/
/*	      Auto detect MyDOS version and use correct boot sectors.	*/
/*	      This needs to be updated for additional versions;		*/
/*	      currently only 4.50 and 4.53 are supported.		*/
/*									*/
/*	      Fixed segfault with directories with > 64 files.		*/
/*									*/
/*	      Fixed a bug in the writing of file data--it's right now	*/
/*									*/
/*	      Cleaned up the MyDOS boot sector data.  It may still	*/
/*	      be sensitive to different versions of MyDOS.		*/
/*									*/
/* 24 Feb 98  Version 0.8   Preston Crow <crow@cs.dartmouth.edu>	*/
/*	      Add '-s' option to skip the first 720 sectors.		*/
/*	      This is useful to protect against corruption from		*/
/*	      files that do raw sector I/O, and to save room to write	*/
/*	      the DOS files.						*/
/*	      Even with this flag, DOS.SYS will be written at sector 4	*/
/*									*/
/*	      VTOC is now generated for DOS2.5 enhanced density images.	*/
/*									*/
/*	      Boot sectors are correct for MyDOS and DOS2.0/2.5,	*/
/*	      except that they aren't adjusted to reflect the disk	*/
/*	      parameters or the existence of DOS.SYS.			*/
/*									*/
/*	      DOS.SYS, DUP.SYS, and AUTORUN.SYS will be the first	*/
/*	      files written if they are found.				*/
/*									*/
/*	      Directory sorting is case-insensitive if '-u' is		*/
/*	      specified, so the resulting image has a sorted directory.	*/
/*									*/
/* 21 Feb 98  Version 0.7   Preston Crow <crow@cs.dartmouth.edu>	*/
/*	      Bug fix:  ATR "sector" count is now correct.		*/
/*	      (Why did they use such a strange formula?)		*/
/*	      Initial writing of boot sector and VTOC.			*/
/*									*/
/*	      Still no support for extended DOS 2.5 VTOC.		*/
/*									*/
/*	      Should include file numbers for non-MyDOS disks.		*/
/*									*/
/*  7 Feb 98  Version 0.6   Preston Crow <crow@cs.dartmouth.edu>	*/
/*            Bug fixes                                                 */
/*									*/
/*  7 Jun 95  Version 0.5   Preston Crow <crow@cs.dartmouth.edu>	*/
/*	      Mostly works except:					*/
/*              MyDos format is the only one that works.                */
/*		bitmaps aren't written to the image			*/
/*		boot sectors aren't created				*/
/*									*/
/************************************************************************/

/************************************************************************/
/* Include files							*/
/************************************************************************/
#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/dir.h>
#include <string.h>
#include <unistd.h>

/************************************************************************/
/* Macros and Constants							*/
/************************************************************************/
#define ATRHEAD 16
#define USAGE "unix2atr [-dumps] #sectors atarifile.atr [directory]\n    Flags:\n\t-d Double density sectors\n\t-u Convert filenames to upper case\n\t-m MyDOS format disk image\n\t-s skip the first 720 sectors\n\t-p print debugging stuff\n"
/* SEEK:  seek offset in the disk image file for a given sector number */
#define SEEK(n)		(ATRHEAD + ((n<4)?((n-1)*128):(3*128+(n-4)*secsize)))

/************************************************************************/
/* Data types								*/
/************************************************************************/
struct atari_dirent {
	unsigned char flag; /* set bits:  
			       7->deleted
			       6->normal file
			       5->locked
			       4->MyDOS subdirectory
			       3->???
			       2->??? \ one for >720, one for >1024 ?
			       1->??? /  all for MyDOS?
			       0->write open */
	unsigned char countlo; /* Number of sectors in file */
	unsigned char counthi;
	unsigned char startlo; /* First sector in file */
	unsigned char starthi;
	char namelo[8];
	char namehi[3];
};

struct atr_head {
	unsigned char h0; /* 0x96 */
	unsigned char h1; /* 0x02 */
	unsigned char seccountlo;
	unsigned char seccounthi;
	unsigned char secsizelo;
	unsigned char secsizehi;
	unsigned char hiseccountlo;
	unsigned char hiseccounthi;
	unsigned char unused[8];
};

/************************************************************************/
/* Function Prototypes							*/
/************************************************************************/
void write_file(FILE *fin,int sector,int fileno);	/* Write a file starting at the specified sector */
void write_dir(int sector);		/* Write a directory */
void set_dos_version(char *fname);	/* Determine which version of DOS.SYS it is */
int use_sector(void);			/* Return a sector number that is free to use after marking it */
int use_8_sector(void);			/* Get 8 sectors for a directory */
void write_boot(void);			/* Write first 3 sectors */
void write_bitmaps(void);		/* Write out the free bitmap */
int afnamecpy(char *an,const char *n);

/************************************************************************/
/* Global variables							*/
/************************************************************************/
int secsize;
int mydos=0;
int upcase=0;
int debug=0;
int seccount;
char bitmap[64*1024]; /* Free "bit" map */
int lastfree=4;
FILE *fout;
int rootdir; /* flag for sorting routine */
int dos=0; /* true if DOS.SYS is written */
int dosver=0; /* DOS.SYS version code */

/************************************************************************/
/* main()								*/
/* Process command line							*/
/* Open input .ATR file							*/
/* Interpret .ATR header						*/
/************************************************************************/
int main(int argc,char *argv[])
{
	struct atr_head head;
	int i;
	unsigned char buf[256];

	--argc; ++argv; /* Skip program name */

	secsize=128;
	/* Process flags */
	while (argc) {
		int done=0;

		if (**argv=='-') {
			++*argv;
			while(**argv) {
				switch(**argv) {
				    case 'd': /* DD */
					secsize=256;
					break;
				    case 'm': /* MyDos disk */
					mydos=1;
					break;
				    case '-': /* Last option */
					done=1;
					break;
				    case 'u': /* strupr names */
					upcase=1;
					break;
				    case 'p': /* debugging */
					debug=1;
					break;
				    case 's': /* skip early sectors */
					lastfree=721;
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
	if (argc<2) {
		fprintf(stderr,USAGE);
		exit(1);
	}

	/* Number of sectors */
	seccount=atoi(*argv);
	++argv;--argc;
	if (seccount<368) {
		fprintf(stderr,USAGE);
		exit(1);
	}


	if ((seccount>1040||(seccount>720&&secsize==256))&&!mydos) {
		fprintf(stderr,"Must use MyDos format if more than 1040 SD or 720 DD sectors\n");
		exit(1);
	}

	/* Open output file */
	fout=fopen(*argv,"wb");
	if (!fout) {
		fprintf(stderr,"Unable to open %s\n%s",*argv,USAGE);
		exit(1);
	}
	--argc; ++argv;

	/* Change directories? */
	if (argc) {
		if (chdir(*argv)) {
			fprintf(stderr,"Unable to change to directory: %s\n%s",*argv,USAGE);
			exit(1);
		}
	}

	/* Initialize free sectors */
	for(i=1;i<=seccount;++i) bitmap[i]=0;
	for(i=seccount+1;i<64*1024;++i) bitmap[i]=1;
	for(i=360;i<=368;++i) bitmap[i]=1;
	for(i=0;i<=3;++i) bitmap[i]=1;
	if (mydos) {
		if (seccount>943+(secsize-128)*8) {
			for(i=360-((seccount-943+(secsize*8-1))/(secsize*8));i<360;++i) bitmap[i]=1;
		}
	}
	else {
		for(i=1024;i<=seccount;++i) {
			bitmap[i]=0; /* Don't use sectors 1024 or above */
		}
	}
	if (!mydos) bitmap[720]=1;

	/* Initialize ATR header */
	head.h0=0x96;
	head.h1=0x02;
	head.secsizelo=secsize&0xff;
	head.secsizehi=secsize/0x100;
	{
		unsigned long paragraphs;

		paragraphs=(seccount-3)*(secsize/16) + 3*128/16;
		head.seccountlo=paragraphs&0xff;
		head.seccounthi=(paragraphs>>8)&0xff;
		head.hiseccountlo=(paragraphs>>16)&0xff;
		head.hiseccounthi=(paragraphs>>24)&0xff;
	}
	bzero(head.unused,sizeof(head.unused));

	fwrite(&head,sizeof(head),1,fout);

	/* Initialize sectors */
	if (debug)printf("Creating %d %d-byte sectors (%d byte file)\n",seccount,secsize,SEEK(seccount)+secsize);
	for(i=0;i<256;++i)buf[i]=0;
	fseek(fout,SEEK(1),SEEK_SET);
	for(i=1;i<=3;++i) fwrite(buf,128,1,fout);
	for(i=4;i<=seccount;++i) fwrite(buf,secsize,1,fout);

	write_dir(361);
	write_boot();
	write_bitmaps();
	return(0);
}

/************************************************************************/
/* write_file()								*/
/* Write a file starting at the specified sector			*/
/************************************************************************/
void write_file(FILE *fin,int sector,int fileno)
{
	unsigned char buf[256];
	int i;
	int sc=1;
	unsigned char c;

	c=fgetc(fin);
	while (!feof(fin)) {
		int nsec=0;
		bzero(buf,secsize);
		if (!mydos) buf[secsize-3]=(fileno<<2);
		for(i=0;i<secsize-3;++i) {
			buf[i]=c;
			++buf[secsize-1];
			c=fgetc(fin);
			if (feof(fin)) break;
		}
		/* Write the sector */
		if (!feof(fin)) {
			nsec=use_sector();
			++sc;
			buf[secsize-2]=nsec%256;
			buf[secsize-3]+=nsec/256; /* add to fileno */
		}
		fseek(fout,SEEK(sector),SEEK_SET);
		fwrite(buf,secsize,1,fout);
		if (nsec && buf[secsize-1]!=secsize-3) {
			printf("Something is very wrong!\n");
			printf("sector:  %d\n",sector);
			printf("nsec:  %d\n",nsec);
			printf("bytes:  %d\n",buf[secsize-1]);
			exit(1);
		}
		if (debug && 0) printf("\t\t\tsector %d -> %d\n",sector,nsec);
		sector=nsec;
	}
	if (debug) printf("\t\tFile written, %d sectors\n",sc);
}

/************************************************************************/
/* mydirsort()								*/
/*									*/
/* Compare two directory entries for use in sorting.			*/
/* Essentially alphabetical ordering, except for special files that	*/
/* go first:  DOS.SYS, DUP.SYS, and AUTORUN.SYS.			*/
/*									*/
/* Note that MyDOS 4.53 seems to use '*AR0' instead of 'AUTORUN.SYS'	*/
/* as the auto-loaded menu program.  I don't know why.			*/
/************************************************************************/
int mydirsort(const struct dirent *const*a,const struct dirent *const*b)
{
	char an[12],bn[12];

	/* If the filename isn't valid for Atari, it's order doesn't matter */
	if (!afnamecpy(an,(*a)->d_name)) return(0);
	if (!afnamecpy(bn,(*b)->d_name)) return(0);

	/* Place certain files first in the root directory */
	if (rootdir) {
		if (strcmp(an,"DOS     SYS")==0) return(-1);
		if (strcmp(bn,"DOS     SYS")==0) return( 1);
		if (strcmp(an,"DUP     SYS")==0) return(-1);
		if (strcmp(bn,"DUP     SYS")==0) return( 1);
		if (strcmp(an,"AUTORUN SYS")==0) return(-1);
		if (strcmp(bn,"AUTORUN SYS")==0) return( 1);
		if (strcmp(an,"AUTORUN AR0")==0) return(-1);
		if (strcmp(bn,"AUTORUN AR0")==0) return( 1);
#if 1 /* force some reordering to make me happy */
		if (strcmp(an,"FILES   LST")==0) return(-1);
		if (strcmp(bn,"FILES   LST")==0) return( 1);
		if (strcmp(an+2,bn+2)==0) return(strcmp(an,bn));
		if (strcmp(an+2,"         ")==0) return( 1);
		if (strcmp(bn+2,"         ")==0) return(-1);
#endif
	}

	/* Compare the converted filenames */
	return(strcmp(an,bn));
}

/************************************************************************/
/* write_dir()								*/
/************************************************************************/
#define SENTRY(n) (secsize==128?n:(n/8)*8+n)
void write_dir(int sector)
{
	struct direct **d;
	int used;
	int i;
	int e;
	int count;
	int start;
	char aname[12];
	struct atari_dirent dir[128]; /* 64 + 64 DD wasted space */
	int lastfreesave=0;

	aname[11]=0;
	for(i=0;i<8*256;++i) ((char *)dir)[i]=0;

	rootdir=(sector==361);
	i=scandir(".",&d,NULL,mydirsort);
	used=0;
	while (i) {
		/* Process **d */
		do {
			struct stat sbuf;
			int subdir;

			/* Hidden files--ignore silently */
			if ((*d)->d_name[0]=='.') break;

			if (lastfreesave) {
				lastfree=lastfreesave;
				lastfreesave=0;
			}

			/* Convert name */
			if (!afnamecpy(aname,(*d)->d_name)) {
				printf("Warning:  %s:  Can't convert to Atari name\n",(*d)->d_name);
				break;
			}

			/* If it's DOS.SYS, start at sector 4, even if we're reserving the first 720 sectors */
			if (rootdir) {
				if (strcmp(aname,"DOS     SYS")==0) {
					set_dos_version((*d)->d_name);
				}
				if (
				    strcmp(aname,"DOS     SYS")==0 ||
				    strcmp(aname,"DUP     SYS")==0 ||
				    strcmp(aname,"AUTORUN SYS")==0
				    ) {
					lastfreesave=lastfree;
					lastfree=3;
				}
			}

			/* Determine if it's a file or directory */
			if (stat((*d)->d_name,&sbuf)) {
				printf("Warning:  %s:  Can't stat file\n",(*d)->d_name);
				break;
			}
			subdir=0;
			if (!sbuf.st_mode&(S_IFDIR|S_IFREG)) {
				printf("Warning:  %s:  Not a normal file or directory\n",(*d)->d_name);
				break;
			}

			if (sbuf.st_mode&S_IFDIR) subdir=1;
			if (subdir && !mydos) {
				printf("Warning:  %s/:  Can't process subdirectory for standard Atari images\n",(*d)->d_name);
				break;
			}

			/* Create the entry */
			e=SENTRY(used);
			if (used>63) {
				printf("Warning:  More than 64 files in this directory\n");
				printf("          Additional files or subdirectories ignored\n");
				return;
			}
			strcpy(dir[e].namelo,aname);
			if (subdir) {
				dir[e].flag=16;
				count=8;
				start=use_8_sector();
			}
			else {
				dir[e].flag=0x46;
				if (!sbuf.st_mode&0000200) dir[e].flag &=32; /* locked */
				count=(sbuf.st_size+(secsize-3)-1)/(secsize-3);
				start=use_sector();
			}
			dir[e].countlo=count&0xff;
			dir[e].counthi=count/0x100;
			dir[e].startlo=start&0xff;
			dir[e].starthi=start/0x100;

			/* Write the directory sector */
			fseek(fout,SEEK(sector),SEEK_SET);
			fwrite(dir,secsize,8,fout);
			++used;

			/* Write the file/subdir */
			if (!subdir) {
				FILE *fin;

				fin=fopen((*d)->d_name,"rb");
				if (!fin) {
					printf("Warning:  %s:  Can't open file\n",(*d)->d_name);
					break;
				}
				if (debug) printf("\tWriting file %s starting at sector %d\n",(*d)->d_name,start);
				write_file(fin,start,used-1);
				fclose(fin);
			}
			else {
				if (debug) printf("\tWriting directory %s\n",(*d)->d_name);
				if (chdir((*d)->d_name)) {
					fprintf(stderr,"Unable to change to directory: %s\n",(*d)->d_name);
					break;
				}
				write_dir(start);
				chdir("..");
			}
		} while(0); /* for break */
		free(*d);
		++d;--i;
	}
}

/************************************************************************/
/* set_dos_version()							*/
/* Read the first K of dos.sys and make an educated guess as to which	*/
/* version it is.							*/
/************************************************************************/
void set_dos_version(char *fname)
{
	FILE *dosfile;
	unsigned char buf[1024];

	dosfile=fopen(fname,"rb");
	if (!dosfile) return;
	fread(buf,1,1024,dosfile);
	fclose(dosfile);
	if (buf[18]==0x08) dosver=450; /* MyDOS 4.50 */
	if (buf[18]==0xFD) dosver=453; /* MyDOS 4.53/4 */
	if (dosver==0) {
		printf("Warning:  Unable to determine DOS.SYS version\n");
	}
	dos=1;
}

/************************************************************************/
/* use_sector()								*/
/* Return a sector number that is free to use after marking it used.	*/
/************************************************************************/
int use_sector(void)
{
	while (lastfree<=seccount&&bitmap[lastfree]) ++lastfree;


	if (lastfree>seccount) {
		fprintf(stderr,"Disk image full\n");
		write_bitmaps();
		exit(1);
	}
	bitmap[lastfree]=1;
	return(lastfree);
}

/************************************************************************/
/* use_8_sector()							*/
/* Get 8 consecutive sectors for a directory				*/
/************************************************************************/
int use_8_sector(void)
{
	int i=lastfree;
	int j;

	while ((bitmap[i+0]||bitmap[i+1]||bitmap[i+2]||bitmap[i+3]||
		bitmap[i+4]||bitmap[i+5]||bitmap[i+6]||bitmap[i+7])
	       && i+7<64*1024) ++i;
	if (i+7<64*1024) {
		for (j=0;j<8;++j) bitmap[i+j]=1;
		return(i);
	}
	fprintf(stderr,"Disk image full--no room for directory\n");
	write_bitmaps();
	exit(1);
}

/************************************************************************/
/* write_boot()								*/
/* Write out the first 3 sectors					*/
/************************************************************************/
void write_boot(void)
{
	/*
	 * Sectors 1 through 3
	 *
	 * Copied from a blank 720-sector DOS2.0S-formatted disk
	 * DOS2.5 generates the same data for 720- and 1040-sector disks.
	 *
	 * Writing DOS files may change some bytes, but I haven't checked
	 * to see which bytes change.
	 */
	char dos20init[128*3]={
		0x00,0x03,0x00,0x07,0x40,0x15,0x4c,0x14,0x07,0x03,0x03,0x00,0x7c,0x1a,0x00,0x04,
		0x00,0x7d,0xcb,0x07,0xac,0x0e,0x07,0xf0,0x36,0xad,0x12,0x07,0x85,0x43,0x8d,0x04,
		0x03,0xad,0x13,0x07,0x85,0x44,0x8d,0x05,0x03,0xad,0x10,0x07,0xac,0x0f,0x07,0x18,
		0xae,0x0e,0x07,0x20,0x6c,0x07,0x30,0x17,0xac,0x11,0x07,0xb1,0x43,0x29,0x03,0x48,
		0xc8,0x11,0x43,0xf0,0x0e,0xb1,0x43,0xa8,0x20,0x57,0x07,0x68,0x4c,0x2f,0x07,0xa9,
		0xc0,0xd0,0x01,0x68,0x0a,0xa8,0x60,0x18,0xa5,0x43,0x6d,0x11,0x07,0x8d,0x04,0x03,
		0x85,0x43,0xa5,0x44,0x69,0x00,0x8d,0x05,0x03,0x85,0x44,0x60,0x8d,0x0b,0x03,0x8c,
		0x0a,0x03,0xa9,0x52,0xa0,0x40,0x90,0x04,0xa9,0x57,0xa0,0x80,0x8d,0x02,0x03,0x8c,
		0x03,0x03,0xa9,0x31,0xa0,0x0f,0x8d,0x00,0x03,0x8c,0x06,0x03,0xa9,0x03,0x8d,0xff,
		0x12,0xa9,0x00,0xa0,0x80,0xca,0xf0,0x04,0xa9,0x01,0xa0,0x00,0x8d,0x09,0x03,0x8c,
		0x08,0x03,0x20,0x59,0xe4,0x10,0x1d,0xce,0xff,0x12,0x30,0x18,0xa2,0x40,0xa9,0x52,
		0xcd,0x02,0x03,0xf0,0x09,0xa9,0x21,0xcd,0x02,0x03,0xf0,0x02,0xa2,0x80,0x8e,0x03,
		0x03,0x4c,0xa2,0x07,0xae,0x01,0x13,0xad,0x03,0x03,0x60,0xaa,0x08,0x14,0x0b,0xbe,
		0x0a,0xcb,0x09,0x00,0x0b,0xa6,0x0b,0x07,0x85,0x44,0xad,0x0a,0x07,0x8d,0xd6,0x12,
		0xad,0x0c,0x07,0x85,0x43,0xad,0x0d,0x07,0x85,0x44,0xad,0x0a,0x07,0x8d,0x0c,0x13,
		0xa2,0x07,0x8e,0x0d,0x13,0x0e,0x0c,0x13,0xb0,0x0d,0xa9,0x00,0x9d,0x11,0x13,0x9d,
		0x29,0x13,0x9d,0x31,0x13,0xf0,0x36,0xa0,0x05,0xa9,0x00,0x91,0x43,0xe8,0x8e,0x01,
		0x03,0xa9,0x53,0x8d,0x02,0x03,0x20,0x53,0xe4,0xa0,0x02,0xad,0xea,0x02,0x29,0x20,
		0xd0,0x01,0x88,0x98,0xae,0x0d,0x13,0x9d,0x11,0x13,0xa5,0x43,0x9d,0x29,0x13,0xa5,
		0x44,0x9d,0x31,0x13,0x20,0x70,0x08,0x88,0xf0,0x03,0x20,0x70,0x08,0xca,0x10,0xb2,
		0xac,0x09,0x07,0xa2,0x00,0xa9,0x00,0x88,0x10,0x01,0x98,0x9d,0x19,0x13,0x98,0x30,
		0x0d,0xa5,0x43,0x9d,0x39,0x13,0xa5,0x44,0x9d,0x49,0x13,0x20,0x70,0x08,0xe8,0xe0,
		0x10,0xd0,0xe2,0xa5,0x43,0x8d,0xe7,0x02,0xa5,0x44,0x8d,0xe8,0x02,0x4c,0x7e,0x08,
		0x18,0xa5,0x43,0x69,0x80,0x85,0x43,0xa5,0x44,0x69,0x00,0x85,0x44,0x60,0xa0,0x7f
	};
	/*
	 * Sectors 1 through 3
	 *
	 * Rick D. <rldetlefsen@delphi.com> reported:
	 > MYDOS will store the same info in the boot sector as any other DOS.  This is
	 > because the OS must use it to locate and load DOS into ram.
	 > Sector 1, byte offset 0-19 hold the useful info.  b14=1=DOS;=0=No DOS,
	 > B15 & 16=sector to start of DOS, B18 & B19=DOS load address, B9= #file buffers,
	 > B10=drive bits, and B17=Disp to sector link(effectivly, disk density).  The
	 > rest of the stuff is either in DOS(ramdisk config), or Mydos guese, i.e. >720
	 > sectors, or double sided.
	 *
	 */
	char mydosinit453[3*128]={
 0x4d,0x03,0x00,0x07,0xe0,0x07,0x4c,0x14,0x07,0x03,0x09,0x01,0xe8,0x1b,0x02,0x04
,0x00,0xfd,0x0a,0x0b,0xac,0x12,0x07,0xad,0x13,0x07,0x20,0x58,0x07,0xad,0x10,0x07
,0xac,0x0f,0x07,0x18,0xae,0x0e,0x07,0xf0,0x1d,0x20,0x63,0x07,0x30,0x18,0xac,0x11
,0x07,0xb1,0x43,0x29,0xff,0x48,0xc8,0x11,0x43,0xf0,0x0e,0xb1,0x43,0x48,0x20,0x4d
,0x07,0x68,0xa8,0x68,0x90,0xdd,0xa9,0xc0,0xa0,0x68,0x0a,0xa8,0x60,0xad,0x11,0x07
,0x18,0x65,0x43,0xa8,0xa5,0x44,0x69,0x00,0x84,0x43,0x85,0x44,0x8c,0x04,0x03,0x8d
,0x05,0x03,0x60,0x8d,0x0b,0x03,0x8c,0x0a,0x03,0xa0,0x03,0xa9,0x52,0x90,0x02,0xa9
,0x50,0x84,0x48,0x8d,0x02,0x03,0x18,0x8c,0x06,0x03,0xa9,0x80,0xca,0xf0,0x0d,0xae
,0x0b,0x03,0xd0,0x07,0xae,0x0a,0x03,0xe0,0x04,0x90,0x01,0x0a,0x8d,0x08,0x03,0x2a
,0x8d,0x09,0x03,0xa0,0x31,0x8c,0x00,0x03,0xc6,0x48,0x30,0x16,0xae,0x02,0x03,0xe8
,0x8a,0xa2,0x40,0x29,0x06,0xd0,0x02,0xa2,0x80,0x8e,0x03,0x03,0x20,0x59,0xe4,0x88
,0x30,0xe6,0xa6,0x2e,0xc8,0x98,0x60,0x10,0x69,0x01,0x00,0x80,0xf6,0x00,0x00,0x00
,0x23,0x28,0x50,0x4d,0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x12,0x52,0xd2,0xd2
,0xd2,0xd2,0xd2,0xd2,0x5c,0x0c,0x5c,0x0e,0x62,0x0d,0xc6,0x0d,0x50,0x0e,0x67,0x10
,0xa9,0x69,0x8d,0xb8,0x07,0xa9,0x01,0x8d,0xb9,0x07,0xa2,0x08,0x8e,0x01,0x03,0x20
,0xb6,0x0b,0xbd,0xcb,0x07,0x30,0x12,0x20,0x9a,0x0b,0xf0,0x0d,0xbd,0xcb,0x07,0xc9
,0x40,0xb0,0x06,0xbc,0xc3,0x07,0x20,0x24,0x0b,0xca,0xd0,0xe0,0xa0,0xae,0x8a,0x99
,0x55,0x08,0x88,0xd0,0xfa,0xee,0x59,0x08,0xad,0x0c,0x07,0x8d,0xe7,0x02,0xac,0x0d
,0x07,0xa2,0x0f,0xec,0x09,0x07,0x90,0x05,0xde,0xdd,0x08,0x30,0x05,0x98,0x9d,0xed
,0x08,0xc8,0xca,0x10,0xee,0x8c,0xe8,0x02,0xe8,0xe8,0xe8,0xbd,0x18,0x03,0xf0,0x04
,0xc9,0x44,0xd0,0xf4,0xa9,0x44,0x9d,0x18,0x03,0xa9,0xd4,0x9d,0x19,0x03,0xa9,0x07
,0x9d,0x1a,0x03,0x4c,0x79,0x1a,0x00,0x00,0xff,0x01,0x00,0x00,0x00,0x00,0x00,0x00
,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xc8,0x80
,0xfd,0x00,0x03,0x04,0x00,0x00,0x00,0x00,0x00,0x69,0x01,0x00,0x00,0x00,0x00,0x00
	};
	char mydosinit450[3*128]={
 0x4d,0x03,0x00,0x07,0xe0,0x07,0x4c,0x14,0x07,0x03,0xff,0x01,0xe9,0x1b,0x02,0x04
,0x00,0xfd,0x15,0x0b,0xac,0x12,0x07,0xad,0x13,0x07,0x20,0x58,0x07,0xad,0x10,0x07
,0xac,0x0f,0x07,0x18,0xae,0x0e,0x07,0xf0,0x1d,0x20,0x63,0x07,0x30,0x18,0xac,0x11
,0x07,0xb1,0x43,0x29,0xff,0x48,0xc8,0x11,0x43,0xf0,0x0e,0xb1,0x43,0x48,0x20,0x4d
,0x07,0x68,0xa8,0x68,0x90,0xdd,0xa9,0xc0,0xa0,0x68,0x0a,0xa8,0x60,0xad,0x11,0x07
,0x18,0x65,0x43,0xa8,0xa5,0x44,0x69,0x00,0x84,0x43,0x85,0x44,0x8c,0x04,0x03,0x8d
,0x05,0x03,0x60,0x8d,0x0b,0x03,0x8c,0x0a,0x03,0xa0,0x03,0xa9,0x52,0x90,0x03,0xad
,0x79,0x07,0x84,0x48,0x8d,0x02,0x03,0x18,0xa9,0x57,0x8c,0x06,0x03,0xa9,0x80,0xca
,0xf0,0x0d,0xae,0x0b,0x03,0xd0,0x07,0xae,0x0a,0x03,0xe0,0x04,0x90,0x01,0x0a,0x8d
,0x08,0x03,0x2a,0x8d,0x09,0x03,0xa0,0x31,0x8c,0x00,0x03,0xc6,0x48,0x30,0x16,0xae
,0x02,0x03,0xe8,0x8a,0xa2,0x40,0x29,0x06,0xd0,0x02,0xa2,0x80,0x8e,0x03,0x03,0x20
,0x59,0xe4,0x88,0x30,0xe6,0xa6,0x2e,0xc8,0x98,0x60,0x10,0x71,0x01,0x00,0x80,0xf6
,0x23,0x28,0x50,0x4d,0x01,0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x52,0x12,0xd2,0xd2
,0xd2,0xd2,0xd2,0xd2,0x5c,0x0c,0x5c,0x0e,0x62,0x0d,0xc6,0x0d,0x50,0x0e,0x67,0x10
,0xa9,0x69,0x8d,0xbb,0x07,0xa9,0x01,0x8d,0xbc,0x07,0xa2,0x08,0x8e,0x01,0x03,0x20
,0xb6,0x0b,0xbd,0xcb,0x07,0x30,0x1d,0x20,0x9a,0x0b,0xf0,0x18,0xa0,0x09,0xb9,0x25
,0x0b,0x99,0x02,0x03,0x88,0x10,0xf7,0xbd,0xcb,0x07,0xc9,0x40,0xb0,0x06,0xbc,0xc3
,0x07,0x20,0x2f,0x0b,0xca,0xd0,0xd5,0xa0,0xae,0x8a,0x99,0x60,0x08,0x88,0xd0,0xfa
,0xee,0x64,0x08,0xad,0x0c,0x07,0x8d,0xe7,0x02,0xac,0x0d,0x07,0xa2,0x0f,0xec,0x09
,0x07,0x90,0x05,0xde,0xe8,0x08,0x30,0x05,0x98,0x9d,0xf8,0x08,0xc8,0xca,0x10,0xee
,0x8c,0xe8,0x02,0xe8,0xe8,0xe8,0xbd,0x18,0x03,0xf0,0x04,0xc9,0x44,0xd0,0xf4,0xa9
,0x44,0x9d,0x18,0x03,0xa9,0xd4,0x9d,0x19,0x03,0xa9,0x07,0x9d,0x1a,0x03,0x4c,0x8c
,0x1a,0x00,0x00,0xff,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xc8,0x80,0xfd,0x00,0x03,0x04,0x00
	};
	char *mydosinit;

	if (debug && mydos) {
		printf("Mydos version:  %d\n",dosver);
	}
	switch (dosver) {
	    case 450:
		mydosinit=mydosinit450;
		break;
	    case 453:
		mydosinit=mydosinit453;
		break;
	    default:
		mydosinit=mydosinit450;
		if (mydos && dos) {
			printf("Warning:  Failed to detect MyDOS version, may not boot\n");
		}
	}
	mydosinit[0]='M'; /* Indicate MyDOS 4.5 or later */
	mydosinit[1]=3; /* number of sectors in the boot */
	mydosinit[9]=3; /* Max number of open files at one time */
	mydosinit450[10]=255; /* Ram Disk unit number */
	mydosinit453[10]=9;   /* Ram Disk unit number */
	mydosinit[11]=1; /* Default unit number (D:) */
	/* [12],[13]:  First byte of free memory */
	mydosinit[14]=((secsize==256)?2:1);
	mydosinit[15]=4;mydosinit[16]=0; /* DOS.SYS start sector */
	mydosinit[17]=secsize-3; /* Offset to the sector link field */
	/* [18],[19]: Address to load dos.sys into */
	if (dos) {
		mydosinit450[18]=21;
		mydosinit453[18]=10;
	}
	/*
	 * The following seemed to be correct based on experimentation:
	 */
	mydosinit453[196]=((secsize==256)?2:1);
	mydosinit453[368]=secsize-3;

	fseek(fout,SEEK(1),SEEK_SET);
	fwrite(mydos?mydosinit:dos20init,128,3,fout);
}

/************************************************************************/
/* write_bitmaps()							*/
/* Write out the free bitmap (VTOC)					*/
/* I'm a bit clueless on much of this, but it tries to do what I've	*/
/* observed from real disk images.					*/
/************************************************************************/
void write_bitmaps(void)
{
	char sec360[256] /******** ={
		0x02,0xc3,0x02,0xc3,0x02,0x00,0x00,0x00,0x00,0x00,0x0f,0xff,0xff,0xff,0xff,0xff,
		0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
		0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
		0xff,0xff,0xff,0xff,0xff,0xff,0xff,0x00,0x7f,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
		0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
		0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,
		0xff,0xff,0xff,0xff,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
		0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00
	}********/;
	int i;
	int byte,bit;
	int free;

	for(i=0;i<256;++i)sec360[i]=0;

	/*
	 * We need to clean up the computation of total data sectors.
	 *
	 * For non-MyDos>720, we need to take into account the second VTOC
	 * For MyDos, we need to count 720, but not additional VTOC sectors.
	 */
	{
		int total;

		total=seccount-3-9-1; /* Boot, VTOC+DIR, 720 */

		if (mydos) {
			total=seccount-3-8; /* boot and dir */
			total-=(1+(seccount-(943+(secsize-128)*8)+(secsize*8-1))/(secsize*8)); /* VTOC */
		}
		else if (seccount>720) {
			if (total>1023-3-8-1-1) total=1023-3-8-1-1;
		}
		sec360[2]=(total)/256;
		sec360[1]=(total)%256;
	}

	/*
	 * Record the number of free sectors
	 * For DOS2.5, this is the number of free sectors in this VTOC.
	 */
	free=0;
	for(i=0;i<=(mydos?seccount:720);++i) {
		if (bitmap[i]==0) ++free;
	}
	sec360[4]=free/256;
	sec360[3]=free%256;
	if (debug) {
		printf("%d sectors %sfree\n",free,mydos?"":"<720 ");
	}

	/*
	 * I'm clueless--is this some sort of version code?
	 * I think this agrees with how MyDOS and DOS2.5 set this byte.
	 */
	sec360[0]=2;
	if (mydos && seccount>943) sec360[0]+=(seccount-943+(secsize*8-1))/(secsize*8)+1;

	/*
	 * bitmap[i] is true if the sector has been used
	 *
	 * The corresponding bit should be one if the sector is *free*
	 */
	if (!mydos) {
		for(i=0;i<720;++i) {
			byte=10+i/8;
			bit=i%8;
			bit=7-bit;
			bit=1<<bit;
			if(bitmap[i]) {
				sec360[byte]&= ~bit;
			}
			else {
				sec360[byte]|=bit;
			}
		}

		/* Write sector 360 */
		fseek(fout,SEEK(360),SEEK_SET);
		fwrite(sec360,128,1,fout);

		if(seccount>720) {
			/* Copy most of first VTOC */
			for(i=0;i<128-16;++i)sec360[i]=sec360[i+16];

			free=0;
			for(i=720;i<1024;++i) {
				byte=i/8-6;
				bit=i%8;
				bit=7-bit;
				bit=1<<bit;
				if(bitmap[i]) {
					sec360[byte]&= ~bit;
					++free;
				}
				else {
					sec360[byte]|=bit;
				}
			}

			/* Record number of free extended sectors */
			sec360[123]=free/256;
			sec360[122]=free%256;

			fseek(fout,SEEK(1024),SEEK_SET);
			fwrite(sec360,128,1,fout);
		}
	}
	else {
		for(i=0;i<=943;++i) {
			byte=10+i/8;
			bit=i%8;
			bit=7-bit;
			bit=1<<bit;
			if(bitmap[i]) {
				sec360[byte]&= ~bit;
			}
			else {
				sec360[byte]|=bit;
			}
		}

		/* Write sector 360 */
		fseek(fout,SEEK(360),SEEK_SET);
		fwrite(sec360,128,1,fout);

		if(seccount>943) {
			int ss;
			int sn=359;
			for(ss=944;ss<=seccount;ss+=8*128,--sn) {
				for(i=0;i<128;++i)sec360[i]=0;
				for(i=0;i<8*128;++i) {
					byte=i/8;
					bit=i%8;
					bit=7-bit;
					bit=1<<bit;
					if(bitmap[i+ss]) {
						sec360[byte]&= ~bit;
					}
					else {
						sec360[byte]|=bit;
					}
				}
				/* Write sector */
				{
					int s,o;
					if (secsize==128) {
						s=sn;
						o=0;
					}
					else {
						/*
						 * Hack for DD sectors
						 */
						s=360-sn;
						o=(s&1)*128;
						s=s/2;
						s=360-s;
					}
					fseek(fout,SEEK(s)+o,SEEK_SET);
					fwrite(sec360,128,1,fout);
				}
			}
		}
	}
}

/************************************************************************/
/* afnamecpy()								*/
/* Convert a Unix filename to an Atari filename.			*/
/* Return 0 on failure.							*/
/************************************************************************/
int afnamecpy(char *an,const char *n)
{
	int i;
	for(i=0;i<11;++i) an[i]=' '; /* Space fill the Atari name */
	an[11]=0;
	for(i=0;i<8;++i) {
		if (!*n) return(1); /* Ok */
		if (*n=='.') break; /* Extension */
		if (*n==':') return(0); /* Illegal name */
		if (upcase) an[i]=toupper(*n);
		else an[i]= *n;
		++n;
	}
	if (*n=='.') ++n;
	for(i=8;i<11;++i) {
		if (!*n) return(1); /* Ok */
		if (*n=='.') return(0); /* Illegal name */
		if (*n==':') return(0); /* Illegal name */
		if (upcase) an[i]=toupper(*n);
		else an[i]= *n;
		++n;
	}
	if (*n) return(0); /* Extension too long or more than 11 characters */
	return(1);
}
