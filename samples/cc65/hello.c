
#include <stdio.h>
#include "lunix.h"

int main(int argv,char **argc)
{                        
int i;

	write(FILENO_STDOUT,"raw write\n\r",11);
	fputs("fputs\n\r",stdout);
	printf("printf\n\r");

	/* print commandline arguments */

	printf("argv: %d\n\r",argv);

	for(i=0;i<argv;i++)
	{
		printf("argc[%d]:%s\n\r",i,argc[i]);

		fputs(argc[i],stdout);

	}

	return(0);
}
