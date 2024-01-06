/*
// This prepares atari.bin (an Atari DOS runable image) from
// lunix.atari and boot.atari (both files in CBM format --
// with loadaddress at the start)
//
// [don't look at the code, it's ugly :)]
//
// Maciej Witkowiak <ytm@elysium.pl>
// 26.12.2000
// 23.11.2002
*/

#include <stdio.h>

char fucking_big_buffer[64000];

int main(int argc, char *argv[]) {

FILE *infile, *outfile;
int len,start=0;

    if (argc<3) {
	printf("usage: %s boot.atari kernel.atari outfile.bin\n",argv[0]);
	exit(1);
    } else {

	outfile = fopen(argv[3],"w");
	if (outfile<0) {
	    printf("couldn't open output file %s\n",argv[3]);
	    exit(2);
	}

	/* write Atari header magic */
	fputc(0xff,outfile); fputc(0xff,outfile);

	infile = fopen(argv[2],"r");
	if (infile<0) {
	    printf("couldn't open input file %s\n",argv[2]);
	    exit(3);
	}

	/* get system image length */
	fseek(infile,0,SEEK_END);
	len = ftell(infile);
	printf("System length:%i\n",len);
	fseek(infile,0,SEEK_SET);

	/* write system loadaddress ($2000) and end address */
	fread(&start,2,1,infile);
	printf("System load:%i\n",start);
	fwrite(&start,2,1,outfile);
	start=start+len-1-2;
	fwrite(&start,2,1,outfile);

	/* copy contents */
	fread(fucking_big_buffer,1,len-2,infile);
	fwrite(fucking_big_buffer,1,len-2,outfile);

	/* close infile */
	fclose(infile);

	/* open second part */
	infile = fopen(argv[1],"r");
	if (infile<0) {
	    printf("couldn't open input file %s\n",argv[1]);
	    exit(4);
	}

	/* get boot image length */
	fseek(infile,0,SEEK_END);
	len = ftell(infile);
	printf("Booter length:%i\n",len);
	fseek(infile,0,SEEK_SET);

	/* write boot loadaddress ($5000) and end address */
	fread(&start,2,1,infile);
	printf("Booter load:%i\n",start);
	fwrite(&start,2,1,outfile);
	start=start+len-1-2;
	fwrite(&start,2,1,outfile);

	/* copy contents */
	fread(fucking_big_buffer,1,len-2,infile);
	fwrite(fucking_big_buffer,1,len-2,outfile);

	fclose(infile);

	/* write execution bits */
	fputc(0xe0,outfile); fputc(0x02,outfile);
	fputc(0xe1,outfile); fputc(0x02,outfile);
	fputc(0x00,outfile); fputc(0x50,outfile);

	fclose(outfile);

	return 0;
    }
}
