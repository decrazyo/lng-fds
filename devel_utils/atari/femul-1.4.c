/*
 * femul:  The Atari Floppy Emulator
 *	   also known as:
 *				SIO2Linux
 *
 * Copyrights are held by the respective authors listed below.
 * Licensed for distribution under the GNU Public License.
 *
 * You need to use sio2pc cable to run this
 *
 *
 * Compilation:
 *	Requires gcc for inline assembly
 *	Only runs on Intel(tm) Pentium(tm) or better processors
 *
 * Currently, this does not support the 'format' or 'verify' SIO
 * commands.
 *
 *
 * Version History:
 *
 * Version 1.4	22 Mar 1998	Preston Crow <crow@cs.dartmouth.edu>
 *
 *	Added support for read-only images.  Any image that can't
 *	be opened for read/write will instead be opened read-only.
 *	Also, if a '-r' option appears before the image, it will
 *	be opened read-only.
 *
 *	Cleaned up a few things.  The system speed is now determined
 *	dynamically, though it still uses the Pentium cycle counter.
 *	A status request will now send write-protect information.
 *	Added a short usage blurb for when no options are specified.
 *
 *	It should be slightly more tollerant of other devices active
 *	on the SIO bus, but it could still confuse it.
 *
 * Version 1.3	20 Mar 1998	Preston Crow <crow@cs.dartmouth.edu>
 *
 *	The status command responds correctly for DD and ED images.
 *
 *	This version is fully functional.  Improvements beyond this
 *	release will focus on adding a nice user interface, and
 *	making it better at recognizing commands, so as to interact
 *	safely with real SIO devices.  A possible copy-protection
 *	mode may be nice, where the program watches all the activity
 *	on D1: while the program loads off of a real device, recording
 *	all data, timing, and status information.  Whether yet another
 *	file format should be used, or some existing format, is an open
 *	matter.
 *
 * Version 1.2	17 Mar 1998	Preston Crow <crow@cs.dartmouth.edu>
 *
 *	I've added in support for checking the ring status after reading
 *	a byte to determine if it is part of a command.  However, as this
 *	requires a separate system call, it may be too slow.  If that proves
 *	to be the case, it may be necessary to resort to direct assembly-
 *	language access to the port (though this would eliminate compatibility
 *	with non-Intel Linux systems).  That seems to not work well; many
 *	commands aren't recognized, at least when using the system call to
 *	check the ring status, so I've implemented a rolling buffer that will
 *	assume it has a command when the last five bytes have a valid checksum.
 *	That may cause problems if a non-SIO2PC drive is used.
 *
 *	It seems to work great for reading SD disk images right now.
 *	I haven't tested writing, but I suspect it will also work.
 *	It has problems when doing DD disk images.  I suspect the
 *	problem has to do with the status command returning hard-coded
 *	information.
 *
 *	The debugging output should be easier to read now, and should always
 *	be printed in the same order as the data is transmitted or received.
 *
 * Version 1.1	Preston Crow <crow@cs.dartmouth.edu>
 *	Lots of disk management added.
 *	In theory, it should handle almost any ATR or XFD disk image
 *	file now, both reading and writing.
 *	Unfortunately, it is quite broken right now.  I suspect timing
 *	problems, though it may be problems with incorrect ACK/COMPLETE
 *	signals or some sort of control signal separate from the data.
 *
 * Version 1.0	Pavel Machek <pavel@atrey.karlin.mff.cuni.cz>
 *
 *	This is Floppy EMULator - it will turn your linux machine into
 *	atari 800's floppy drive. Copyright 1997 Pavel Machek
 *	<pavel@atrey.karlin.mff.cuni.cz> distribute under GPL.
 */


/*
 * Standard include files
 */
#include <stdio.h>
#include <termio.h>
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>
#include <unistd.h>
#include <ctype.h>
#include <string.h>
#include <sys/types.h>
#include <sys/timeb.h>
#include <sys/stat.h>
#include <sys/ioctl.h>
#include <sys/stat.h>

/*
 * Data structures
 */
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

enum seekcodes {
	xfd,	/* This is a xfd (raw sd) image */
	atr,	/* This is a regular ATR image */
	atrdd3	/* This is a dd ATR image, including the first 3 sectors */
};

/*
 * Prototypes
 */
static void err(const char *s);
static void raw(int fd);
static void ack(unsigned char c);
static void senddata(int disk,int sec);
static void sendrawdata(unsigned char *buf,int size);
static void recvdata(int disk,int sec);
static int get_atari(void);
void getcmd(unsigned char *buf);
static void loaddisk(char *path,int disk);
static void decode(unsigned char *buf);
int iscmd(void);
void getcmd1(unsigned char *buf);
void myusleep(int us);
void mysleepinit(void);

/*
 * Macros
 */
#define SEEK(n,i)		(seekcode[i]==xfd)?SEEK0(n,i):((seekcode[i]=atr)?SEEK1(n,i):SEEK2(n,i))
#define SEEK0(n,i)	((n-1)*secsize[i])
#define SEEK1(n,i)	(ATRHEAD + ((n<4)?((n-1)*128):(3*128+(n-4)*secsize[i])))
#define SEEK2(n,i)	(ATRHEAD + ((n-1)*secsize[i]))
#define ATRHEAD		16
#define MAXDISKS	8


/*
 * Default Timings from SIO2PC:
 *	Time before first ACK:	   85us
 *	Time before second ACK:  1020us
 *	Time before COMPLETE:	  255us
 *	Time after COMPLETE:	  425us
 */
#define ACK1 85
#define ACK2 1020
#define COMPLETE1 255
#define COMPLETE2 425

/*
 * Global variables
 */
static int secsize[MAXDISKS];
static int seccount[MAXDISKS];
static enum seekcodes seekcode[MAXDISKS];
static int diskfd[MAXDISKS];
static int ro[MAXDISKS];
static int atari; /* fd of the serial port hooked up to the SIO2PC cable */


/*
 * usleep()
 *
 * This should block for the specified number of microseconds.
 * However, under Linux without RT extensions, this will likely
 * give up the timeslice, resulting in a 10ms delay.  Hence,
 * I've rewritten the function to busy-wait for the required
 * time, based on the Pentium cycle-counter.
 * This will only work on true Intel(tm) Pentium or better x86 chips.
 *
 * For now, the processor speed is hard coded, but it could easily
 * be dynamically-determined by counting the cycles elapsed during
 * a sleep(1) call and dividing by a million.
 */
#define cyclecount(llptr) ({                                    \
  __asm__ __volatile__ (                                        \
        "\t.byte 0x0f; .byte 0x31 # RDTSC instruction\n"        \
        "\tmovl    %%edx,%0       # High order 32 bits\n"       \
        "\tmovl    %%eax,%1       # Low order 32 bits\n"        \
        : "=g" (*(((unsigned *)llptr)+1)), "=g" (*(llptr))      \
        : /* No inputs */                                       \
        : "eax", "edx");})
#define usleep(a) myusleep(a)
static long long hz;
void mysleepinit(void)
{
	long long start;

	cyclecount(&start);
	sleep(1);
	cyclecount(&hz);
	hz -= start;
}

void myusleep(int us)
{
	long long now;
	long long cycles;

	cyclecount(&now);
	cycles=now+hz*us/1000000;
	do {
		cyclecount(&now);
	} while (now<cycles);
}

/*
 * main()
 *
 * Read the command line, open the disk images, connect to the Atari,
 * and listen for commands.
 *
 * This never terminates.
 */
int main(int argc,char *argv[])
{
	int i;
	int numdisks=0;

	if (argc==1) {
		fprintf(stderr,"SIO2Linux:  The Atari floppy drive emulator\n");
		fprintf(stderr,"Usage:\n\t%s [-r] d1_image [-r] d2_image ... [-r] d8_image\n\t-r\tThe next image is to be loaded read-only\n",argv[0]);
		fprintf(stderr,"The port is hard-wired to /dev/ttyS0, but it will switch to /dev/ttyS1\nif /dev/mouse is a link to the first serial port\n");
		fprintf(stderr,"This program uses the Pentium(tm) cycle counter, so it will only\nrun on genuine Intel(tm) Pentium or better procesors.\n");
		exit(1);
	}

	mysleepinit();
	setvbuf(stdout,NULL,_IONBF,0);
	setvbuf(stderr,NULL,_IONBF,0);

	for(i=0;i<MAXDISKS;++i) {
		diskfd[i]= -1;
		ro[i]=0;
	}
	for(i=1;i<argc;i++) {
		if (*(argv[i]) == '-') {
			switch( (argv[i])[1] ) {
			    case 'r':
				ro[numdisks]=1;
				break;
			    default:
				err( "Bad command line argument." );
			}
		}
		else {
			loaddisk(argv[i],numdisks);
			numdisks++;
		}
	}

	atari=get_atari();

	/*
	 * Main control loop
	 *
	 * Read a command and deal with it
	 * The command frame is 5 bytes.
	 */
	while( 1 ) {
		unsigned char buf[5];

		getcmd(buf);
		decode(buf);
	}
	return 0;
}

static void err(const char *s)
{
	fprintf(stderr,"%d:", errno );
	fprintf(stderr,"%s\n", s );
	exit(1);
}

static void raw(int fd)
{
	struct termios it;

	if (tcgetattr(fd,&it)<0) {
		perror("tcgetattr failed");
		err( "get attr" );
	}
	it.c_lflag &= 0; /* ~(ICANON|ISIG|ECHO); */
	it.c_iflag &= 0; /* ~(INPCK|ISTRIP|IXON); */
	/* it.c_iflag |= IGNPAR; */
	it.c_oflag &=0; /* ~(OPOST); */
	it.c_cc[VMIN] = 1;
	it.c_cc[VTIME] = 0;

	if (cfsetospeed( &it, B19200 )<0) err( "set o speed" );
	if (cfsetispeed( &it, B19200 )<0) err( "set i speed" );
	if (tcsetattr(fd,TCSANOW,&it)<0) err( "set attr" );
}

static void ack(unsigned char c)
{
	printf("[");
	if (write( atari, &c, 1 )<=0) err( "ack failed\n" );
	printf("%c]",c);
}

static void senddata(int disk,int sec)
{
	char buf[256];
	int size;
	off_t check,to;
	int i;

	size=secsize[disk];
	if (sec<=3) size=128;

	to=SEEK(sec,disk);
	check=lseek(diskfd[disk],to,SEEK_SET);
	if (check!=to) {
		if (errno) perror("lseek");
		fprintf(stderr,"lseek failed, went to %ld instead of %ld\n",check,to);
		exit(1);
	}
	/* printf("-%d-",check); */
	i=read(diskfd[disk],buf,size);
	if (i!=size) {
		if (i<0) perror("read");
		fprintf(stderr,"Incomplete read\n");
		exit(1);
	}
	sendrawdata(buf,size);
}

static void sendrawdata(unsigned char *buf,int size)
{
	int i, sum = 0;
	int c=0;

	for( i=0; i<size; i++ ) {
		c=write(atari,&buf[i],1);
		if (c!=1) {
			if (errno) perror("write");
			fprintf(stderr,"write failed\n");
			exit(1);
		}
		sum+=buf[i];
		sum = (sum&0xff) + (sum>>8);
	}
	write( atari, &sum, 1 );
	if (c!=1) {
		if (errno) perror("write");
		fprintf(stderr,"write failed\n");
		exit(1);
	}
	printf("-%d bytes+sum-",size);
}

static void recvdata(int disk,int sec)
{
	int i, sum = 0;
	unsigned char mybuf[ 2048 ];
	int size;

	size=secsize[disk];
	if (sec<=3) size=128;

	for( i=0; i<size; i++ ) {
		read( atari, &mybuf[i], 1 );	
		sum = sum + mybuf[i];
		sum = (sum & 0xff) + (sum >> 8);
	}
	read(atari,&i,1);
	if ((i & 0xff) != (sum & 0xff)) printf( "[BAD SUM]" );
	else {
		lseek(diskfd[disk],SEEK(sec,disk),SEEK_SET);
		i=write(diskfd[disk],mybuf,size);
		if (i!=size) printf("[write failed: %d]",i);
	}
	printf("-%d bytes+sum recvd-",size);
}

/*
 * get_atari()
 *
 * Open the serial device and return the file descriptor.
 * It assumes that it is /dev/ttyS0 unless there's a symlink
 * from /dev/mouse to that, in which case /dev/ttyS1 is used.
 */
static int get_atari(void)
{
	int fd;
	char portname[64]="/dev/ttyS2";
/*
//	struct stat stat_mouse,stat_tty;
//	if (stat("/dev/mouse",&stat_mouse)==0) {
//		stat(portname,&stat_tty);
//		if (stat_mouse.st_rdev==stat_tty.st_rdev) {
//			char *c;
//
//			printf("/dev/ttyS0 is the mouse, using ttyS1\n");
//			c=index(portname,'0');
//			*c='1';
//		}
//	}
*/
	fd = open(portname,O_RDWR);
	if (fd<0) {
		fprintf(stderr,"Can't open %s\n",portname);
		exit(1);
	}
	raw(fd); /* Set up port parameters */
	return(fd);
}

/*
 * getcmd()
 *
 * Read one 5-byte command
 *
 * The Atari will activate the command line while sending
 * the 5-byte command, which is detected as the ring indicator
 * by the iscmd() function.
 * What we do is read on byte, and if the command line is active
 * immediately after reading the byte, we assume that that byte
 * was the first of a 5-byte command.  Otherwise, we assume that
 * that was a data byte going to or from another device.
 *
 * The second version of this function reads bytes until it gets
 * a block of 5 that have a correct checksum, and assume that that
 * represents a command regardless of the setting of the command
 * line.
 */
void getcmd1(unsigned char *buf)
{
	int data=0;
	int i,r;
	int sum;

again:
	do {
		if (data) {
			printf("%02x ",*buf);
		}
		++data;
		r=read(atari,buf,1);
		if (r!=1) {
			printf(" -> read returned %d\n",r);
		}
	} while (!iscmd());
	if (data>1) printf("-> %d data bytes\n",data-1);
	for(i=1;i<5;) {
		r=read(atari,buf+i,5-i);
		if (r>0) i+=r;
		else {
			printf("read returned %d\n",r);
		}
	}
	sum=0;
	for(i=0;i<4;++i) {
		sum+=buf[i];
		sum = (sum&0xff) + (sum>>8);
	}
	if (buf[4]!=sum) {
		printf( "checksum mismatch [%02x %02x %02x %02x %02x (%02x)]\n",buf[0],buf[1],buf[2],buf[3],buf[4],sum);
		goto again;
	}
}

void getcmd(unsigned char *buf)
{
	int data=0;
	int i,r;
	unsigned char bigbuf[1024];

	i=0;

	while (1) {
		if (data) printf("-> %d data bytes\n",data),data=0;

		/*
		 * Make sure we have at least 5 bytes
		 */
		while (i<5) {
			r=read(atari,bigbuf+i,sizeof(bigbuf)-i);
			if (r>0) i+=r;
			else {
				perror("read from serial port failed");
				fprintf(stderr,"read returned %d\n",r);
				exit(1);
			}
		}

		/*
		 * Copy them to the command buffer
		 */
		buf[0]=bigbuf[i-5];
		buf[1]=bigbuf[i-4];
		buf[2]=bigbuf[i-3];
		buf[3]=bigbuf[i-2];
		buf[4]=bigbuf[i-1];

		for(r=0;r<i-5;++r) {
			printf("%02x ",bigbuf[r]);
			++data;
		}

		/*
		 * Compute the checksum
		 */
		{
			int sum=0;

			for(i=0;i<4;++i) {
				sum+=buf[i];
				sum = (sum&0xff) + (sum>>8);
			}
			if (buf[4]==sum) {
				if (data) printf("-> %d data bytes\n",data);
				return;
			}
		}

		/*
		 * Get ready to read some more
		 */
		printf("%02x ",buf[0]);
		++data;
		bigbuf[0]=buf[1];
		bigbuf[1]=buf[2];
		bigbuf[2]=buf[3];
		bigbuf[3]=buf[4];
		i=4;
	}
}

/*
 * loaddisk()
 *
 * Ready a disk image.
 * The type of file (xfd/atr) is determined by the file size.
 */
static void loaddisk(char *path,int disk)
{
	if (disk>=MAXDISKS) {
		fprintf(stderr,"Attempt to load invalid disk number %d\n",disk+1);
		exit(1);
	}

	diskfd[disk]=open(path,ro[disk]?O_RDONLY:O_RDWR);
	if (diskfd[disk]<0 && !ro[disk]) {
		ro[disk]=1;
		diskfd[disk]=open(path,ro[disk]?O_RDONLY:O_RDWR);
	}

	if (diskfd[disk]<0) {
		fprintf(stderr,"Unable to open disk image %s\n",path);
		exit(1);
	}

	/*
	 * Determine the file type based on the size
	 */
	secsize[disk]=128;
	{
		struct stat buf;

		fstat(diskfd[disk],&buf);
		seekcode[disk]=atrdd3;
		if (((buf.st_size-ATRHEAD)%256)==128) seekcode[disk]=atr;
		if (((buf.st_size)%128)==0) seekcode[disk]=xfd;
		seccount[disk]=buf.st_size/secsize[disk];
	}

	/*
	 * Read disk geometry
	 */
	if (seekcode[disk]!=xfd) {
		struct atr_head myatr;
		long paragraphs;

		read(diskfd[disk],&myatr,sizeof(myatr));
		secsize[disk]=myatr.secsizelo+256*myatr.secsizehi;
		paragraphs=myatr.seccountlo+myatr.seccounthi*256+
			myatr.hiseccountlo*256*256+myatr.hiseccounthi*256*256*256;
		if (secsize[disk]==128) {
			seccount[disk]=paragraphs/8;
		}
		else {
			paragraphs+=(3*128/16);
			seccount[disk]=paragraphs/16;
		}
	}

	printf( "Disk image %s opened%s (%d %d-byte sectors)\n",path,ro[disk]?" read-only":"",seccount[disk],secsize[disk]);
}

/*
 * decode()
 *
 * Given a command frame (5-bytes), decode it and
 * do whatever needs to be done.
 */
static void decode(unsigned char *buf)
{
	int disk = -1, rs = -1, printer = -1;
	int sec;

	printf( "%02x %02x %02x %02x %02x ",buf[0],buf[1],buf[2],buf[3],buf[4]);

	switch( buf[0] ) {
	    case 0x31: printf( "D1: " ); disk = 0; break;
	    case 0x32: printf( "D2: " ); disk = 1; break;
	    case 0x33: printf( "D3: " ); disk = 2; break;
	    case 0x34: printf( "D4: " ); disk = 3; break;
	    case 0x35: printf( "D5: " ); disk = 4; break;
	    case 0x36: printf( "D6: " ); disk = 5; break;
	    case 0x37: printf( "D7: " ); disk = 6; break;
	    case 0x38: printf( "D8: " ); disk = 7; break;
	    case 0x40: printf( "P: " ); printer = 0; break;
	    case 0x41: printf( "P1: " ); printer = 0; break;
	    case 0x42: printf( "P2: " ); printer = 1; break;
	    case 0x43: printf( "P3: " ); printer = 2; break;
	    case 0x44: printf( "P4: " ); printer = 3; break;
	    case 0x45: printf( "P5: " ); printer = 4; break;
	    case 0x46: printf( "P6: " ); printer = 5; break;
	    case 0x47: printf( "P7: " ); printer = 6; break;
	    case 0x48: printf( "P8: " ); printer = 7; break;
	    case 0x50: printf( "R1: " ); rs = 0; break;
	    case 0x51: printf( "R2: " ); rs = 1; break;
	    case 0x52: printf( "R3: " ); rs = 2; break;
	    case 0x53: printf( "R4: " ); rs = 3; break;
	    default: printf( "???: ignored\n");return;
	}
	if (disk>=0&&diskfd[disk]<0) { printf( "[no image for this drive]\n" ); return; }
	if (printer>=0) {printf("[Printers not supported]\n"); return; }
	if (rs>=0) {printf("[Serial ports not supported]\n"); return; }

	sec = buf[2] + 256*buf[3];

	switch( buf[1] ) {
	    case 0x52:
		printf("read sector %d: ",sec);
		usleep(ACK1);
		ack('A');
		usleep(COMPLETE1);
		ack('C');
		usleep(COMPLETE2);
		senddata(disk,sec);
		break;
	    case 0x57: 
		printf("write sector %d: ",sec);
		usleep(ACK1);
		if (ro[disk]) {
			ack('N');
			printf("[Read-only image]");
			break;
		}
		ack('A');
		recvdata(disk,sec);
		ack('A');
		ack('C');
		break;
	    case 0x53: 
		printf( "status:" ); 
		usleep(ACK1);
		ack(0x41);
		{
			/*
			 * Bob Woolley wrote on comp.sys.atari.8bit:
			 *
			 * at your end of the process, the bytes are
			 * CMD status, H/W status, Timeout and unused.
			 * CMD is the $2EA value previously
			 * memtioned. Bit 7 indicates an ED disk.  Bits
			 * 6 and 5 ($6x) indicate DD. Bit 3 indicates
			 * write protected. Bits 0-2 indicate different
			 * error conditions.  H/W is the FDD controller
			 * chip status.  Timeout is the device timeout
			 * value for CIO to use if it wants.
			 *
			 * So, I expect you want to send a $60 as the
			 * first byte if you want the OS to think you
			 * are in DD. OK?
			 */
			static char status[] = { 0x10, 0x00, 1, 0 };
			status[0]=(secsize[disk]==128?0x10:0x60);
			if (secsize[disk]==128 && seccount[disk]>720) status[0]=0x80;
			if (ro[disk]) {
				status[0] |= 8;
			}
			else {
				status[0] &= ~8;
			}
			usleep(COMPLETE1);
			ack(0x43);
			usleep(COMPLETE2);
			sendrawdata(status,sizeof(status));
		}
		break;
	    case 0x50: 
		printf("put sector %d: ",sec); 
		usleep(ACK1);
		if (ro[disk]) {
			ack('N');
			printf("[Read-only image]");
			break;
		}
		ack('A');
		recvdata(disk, sec);
		ack('A');
		ack('C');
		break;
	    case 0x21: 
		printf( "format " ); 
		break;
	    case 0x20: 
		printf( "download " ); 
		break;
	    case 0x54: 
		printf( "readaddr " ); 
		break;
	    case 0x51: 
		printf( "readspin " ); 
		break;
	    case 0x55: 
		printf( "motoron " ); 
		break;
	    case 0x56: 
		printf( "verify " ); 
		break;
	    default:
		printf( "??? " );
		break;
	}
	printf( "\n" );
}

/*
 * iscmd()
 *
 * returns true if the SIO command line is set (i.e., the modem ring indicator) */
int iscmd(void)
{
	int r;

	ioctl(atari,TIOCMGET,&r);
	if (0) {
		printf("modem status: ");
		if (r&TIOCM_LE) printf(" LE");
		if (r&TIOCM_DTR) printf(" DTR");
		if (r&TIOCM_RTS) printf(" RTS");
		if (r&TIOCM_ST) printf(" ST");
		if (r&TIOCM_SR) printf(" SR");
		if (r&TIOCM_CTS) printf(" CTS");
		if (r&TIOCM_CAR) printf(" CAR");
		if (r&TIOCM_RNG) printf(" RNG");
		if (r&TIOCM_DSR) printf(" DSR");
		printf("\n");
	}
	return(r&TIOCM_RNG);
}
