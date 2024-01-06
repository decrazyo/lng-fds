/*

  Extracter for a certain type of sfx on the c64

  */

#include <stdio.h>

FILE *f;
FILE *o;
char temp[1024];
int i;
int size;

int main(int argc,char **argv)
{
  if (argc<2)
    {
      printf("usage: %s <file>\n",argv[0]);
      exit(1);
    }

  if ((f=fopen(argv[1],"r"))==NULL)
    {
      printf("Cannot open %s\n",argv[1]);
      exit(1);
    }

  /* skip guff */
  for(i=0;i<0x18e;i++) fgetc(f);

  /* read file loop */
  while(!feof(f))
    {
      /* read filename */
      i=0;
      temp[i]=fgetc(f);
      while((temp[i])&&(!feof(f)))
	temp[++i]=fgetc(f);
      if (feof(f))
	return(0);
      if (temp[0]==0) return(0);
      size=fgetc(f);
      size+=256*fgetc(f);
      if (feof(f)) return(0);
      printf("Extracting [%s]\n",temp);
      o=fopen(temp,"w");
      for(i=0;i<size;i++) fputc(fgetc(f),o);
      /* and one extra char for good measure */
      fgetc(f);
      if (feof(f)) return(0);
      
    }
  return(0);

}

