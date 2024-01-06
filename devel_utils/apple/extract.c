#include <stdio.h>
#include <strings.h>
#include <sys/types.h>
#include <string.h>
#include <stdlib.h>

int main(int argc, char *argv[])
{
  FILE *fp;
  char *filename;
  int program_loc;
  int cnt = 0;
  int bytes = 0;

  if( argc == 1 )
  {
    fprintf( stderr, "%s: no arguments, assuming file a.o65, start 768\n",
	argv[0] );
    filename = "a.o65";
    program_loc = 768;
  }
  else if( argc == 2 )
  {
    if( !strcmp( argv[1], "-h" ) )
    {
      fprintf( stderr, "usage: %s <program name> <decimal start addr>\n",
	argv[0] );
      exit(1);
    }

    fprintf( stderr, "%s: missing start argument, assuming 768\n", argv[0] );
    filename = argv[1];
    program_loc = 768;
  }
  else if( argc != 3 )
  {
    fprintf( stderr, "usage: %s <program name> <decimal start addr>\n",
	argv[0] );
    exit(1);
  }
  else
  {
    filename = argv[1];
    program_loc = atoi(argv[2]);
  }


  if( (fp = fopen( filename, "r" )) == NULL )
  {
    perror( filename );
    exit(1);
  }

  do
  {
    u_int8_t data;

    if( cnt == 0 )
      fprintf( stderr, "%04X:", program_loc );

    fread( &data, sizeof(u_int8_t), 1, fp );
    bytes++;
    fprintf( stderr, "%02X ", data );
    cnt++;
    if( cnt == 16 )
    {
      fprintf( stderr, "\n" );
      cnt = 0;
    }

    program_loc++;

  } while( !feof(fp) );

  if( cnt != 16 )
    fprintf( stderr, "\n" );

  fprintf( stderr, "\n%s: total size: %d bytes (%x bytes)\n", filename,
	bytes, bytes );

  fclose(fp);
  exit(1);
}
 
