/* Copyright 1997 Ken Siders */
/* Modified 2002 by Jeffry Johnston to make code ANSI compliant */

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "makeatr.h"


/********************************************************************
 CreateBootAtr - creates a minimally sized bootable ATR image from
                 an atari executable.  The executable must not need
                 DOS to run.
********************************************************************/

int CreateBootAtr( char *atrName, char *fileName)
   {
   unsigned long fileSize;
   unsigned long sectorCnt;
   AtrHeader hdr;
   unsigned long paras;
   FILE * atrFile, *inFile;
   size_t padding, bytes, bytes2;

/* open the input file */

   inFile = fopen(fileName, "rb");
   if ( inFile == NULL )
      {
      fclose(atrFile);
      return 13;
      }

/* get file's size */
   if ( fseek(inFile, 0L, SEEK_END) )
      return 11;

   fileSize = (unsigned) ftell(inFile);
   if ( fileSize == (unsigned) -1 )
       return 12;

   rewind(inFile);

/* determine number of sectors required  */

   sectorCnt = (unsigned short) ((fileSize + 127L) / 128L + 3L);
   paras = sectorCnt * 8; /* bug fix -JLJ- */

/* create ATR header */
   memset(&hdr, 0, sizeof(hdr));
   hdr.idLow      = (byte) 0x96;
   hdr.idHigh     = (byte) 0x02;
   hdr.paraLow    = (byte) (paras & 0xFF);
   hdr.paraHigh   = (byte) ((paras >> 8) & 0xFF);
   hdr.paraHigher = (byte) ((paras >> 16) & 0xFF);
   hdr.secSizeLow = (byte) 128;

/* open output file */
   atrFile = fopen(atrName, "wb");
   if ( atrFile == NULL )
      return 1;

/* Write the ATR Header */
   bytes = fwrite(&hdr, 1, sizeof(hdr), atrFile);
   if ( bytes != sizeof(hdr) )
      {
      fclose(atrFile);
      return 2;
      }

/* plug the file size into the boot sectors at offset 9 (4 bytes)*/
   bootData[9]  = (byte)(fileSize & 255);
   bootData[10] = (byte)((fileSize >> 8) & 255);
   bootData[11] = (byte)((fileSize >> 16) & 255);
   bootData[12] = 0;

/* write the three boot sectors */
   bytes = fwrite(bootData, 1, 384, atrFile);
   if ( bytes != 384 )
      {
      fclose(atrFile);
      return 6;
      }

/* copy/append the file's data to output file */

   bytes = 384;
   while (bytes == 384)
      {
      bytes = fread(bootData, 1, 384, inFile);
      if ( !bytes )
         break;
      bytes2 = fwrite(bootData, 1, bytes, atrFile);
      if ( bytes != bytes2 )
         {
         fclose(inFile);
         fclose(atrFile);
         return 19;
         }
      }
   if ( !feof(inFile) )
      {
      fclose(inFile);
      fclose(atrFile);
      return 19;
      }

  fclose(inFile);


/* pad to even sector size (data has no meaning) */
   padding = (size_t) ((sectorCnt-3) * 128 - fileSize );
   if ( padding )
      {
      bytes = fwrite(bootData, 1, padding, atrFile);
      if ( bytes != padding )
         {
         fclose(atrFile);
         return 7;
         }
      }

/* close output */
   fclose(atrFile);

   return 0;
   }

/********************************************************************
 Main
********************************************************************/

int main( int argc, char **argv)
   {
   int stat = 0;

   printf("MakeAtr Version 0.9-1  (c)1997 Ken Siders\n");
   printf("This program may be freely distributed\n\n");


   if (argc != 3)
      {
      printf("usage: makeatr atrname.atr file\n\n");
      }
   else
      {
      stat = CreateBootAtr( argv[1], argv[2] );
      if ( stat )
         {
         printf("Error #%d encountered in conversion\n\n", stat);
         return EXIT_FAILURE;
         }
      printf("No errors, %s created successfully\n\n", argv[1]);
      }

   return EXIT_SUCCESS;
}

