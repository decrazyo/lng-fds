#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h> /*for u_int8_t*/
#include <unistd.h>
#include <getopt.h>

int verbose = 0;
int phys2log[] = {0x00, 0x0D, 0x0B, 0x09, 0x07, 0x05, 0x03, 0x01,
		 0x0E, 0x0C, 0x0A, 0x08, 0x06, 0x04, 0x02, 0x0F };

void format_disk( FILE **fp );
void dump_block( FILE **fp, int track, int sector );
void insert_binary( FILE **fp, char *binaryfile, int track, int sector );
void sanity_check( int track, int sector );
void usage( void );

void format_disk( FILE **fp )
{
  u_int8_t blank = '\0';
  int loop;

  fseek( *fp, 0, 0 );

  for( loop = 143360; loop != 0; loop-- )
    fputc( blank, *fp );

  return;
}


void insert_binary( FILE **fp, char *binaryfile, int track, int sector )
{
  FILE *binary_fp;
  u_int8_t data;
  int loop;

  if( (binary_fp = fopen(binaryfile, "r")) == NULL )
    { perror( "binaryfile" ); return; }

  while( !feof(binary_fp) )
  {
    if( verbose >= 1 )
      printf( "Dumping to track %d (%02Xh), sector %d (%02Xh)\n",
	track, track, sector, sector );

    /* why not need phys2log??? */
    fseek( *fp, (track*4096 + sector*256), 0 );
    for( loop = 0; loop < 256; loop++ )
    {
      data = fgetc(binary_fp);
      if( feof(binary_fp) )
	break;
      fputc( data, *fp );
    }

    if( ++sector == 16 )
    {
      sector = 0;
      if( ++track == 35 )
      {
	printf( "warning.. binary file past end of disk!\n" );
	return;
      }

    }
  }

  fclose( binary_fp );
  return;
}


void dump_block( FILE **fp, int track, int sector )
{
  u_int8_t data;
  int loop;

  if( verbose >= 1 )
    printf( "Reading from track %d (%02Xh), sector %d (%02Xh)\n",
	track, track, sector, sector );

  fseek( *fp, (track*4096 + sector*256), 0 );
  for( loop = 0; loop < 256; loop++ )
  {
    if( (loop % 16) == 0 )
      printf( "\n%02X: ", loop );
    if( feof(*fp) )
    {
      fprintf( stderr, "error: end of file reached\n" );
      return;
    }

    data = fgetc(*fp);
    printf( "%02X ", data );
  }

  printf( "\n" );
  return;
}

int main( int argc, char *argv[] )
{
  extern char *optarg;
  int ch;

  int formatdisk = 0;
  int dumpblock = 0;
  int examinedisk = 0;
  int track = -1;
  int sector = -1;
  char *binary = NULL;
  char *disk = NULL;
  FILE *disk_fp;
  char *open_mode;

  disk = argv[1];

  while( (ch = getopt(argc-1, &argv[1], "vdfdxb:t:s:")) != -1 ) 
    switch(ch)
      {
      case 'v': { verbose = 1; break; }
      case 'f': { formatdisk = 1; break; }
      case 'd': { dumpblock = 1; break; }
      case 'x': { examinedisk = 1; break; }
      case 'b': { binary = optarg; break; }
      case 't': { track = atoi(optarg);	break; }
      case 's': { sector = atoi(optarg); break; }
      case '?':
      case 'h':
      default:
	usage();
      }
  
  if( disk == NULL )
  {
    fprintf( stderr, "error: no disk image specified\n" );
    exit(1);
  }

  if( formatdisk )
    open_mode="w+";
  else
    open_mode="r+";

  if( (disk_fp = fopen(disk, open_mode)) == NULL )
  {
    perror( disk );
    exit(1);
  }

  if( formatdisk )
    format_disk( &disk_fp );

  if( binary != NULL )
  {
    sanity_check( track, sector );
    insert_binary( &disk_fp, binary, track, sector );
  }

  if( dumpblock )
  {
    sanity_check( track, sector );
    dump_block( &disk_fp, track, sector );
  }

  fclose( disk_fp );
  return 0;
}


void usage( void )
{
  puts( "Diskimage, by Mouse (mouse@whiskers.com\n" );

  puts( "Usage:" );
  puts( "  diskimage <disk.dsk> [-f] [-x] [-v] [[-d] [-b] -t<track> -s<sector>]\n" );

  puts( "General Options:" );
  puts( "  -v: Be verbose about disk statistics" );

  puts( "Command Options:" );
  puts( "  -f: Format disk" );
  puts( "  -D: Dump disk block (requires -t and -s)" );
  puts( "  -x: EXamine disk properties" );
  puts( "  -b <file>: Insert binary data into a disk (requires -t and -s)" );
  puts( "  -t <track>: Specify track (in decimal)" );
  puts( "  -s <sector>: Specify sector (in decimal)" );
  exit(1);
}


void sanity_check( int track, int sector )
{
  if( !(track >= 0 && track <= 35) )
  {
    fprintf( stderr, "error: track must be between 0 and 35..\n" );
    exit(1);
  }

  if( !(sector >= 0 && sector <= 16) )
  {
    fprintf( stderr, "error: sector must be between 0 and 16..\n" );
    exit(1);
  }

  return;
}

  
