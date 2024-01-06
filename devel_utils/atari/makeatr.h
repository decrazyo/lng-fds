/* Copyright 1997 Ken Siders */

struct S_AtrFile {
   FILE *atrIn;
   unsigned long  imageSize;
   unsigned short secSize;
   unsigned long crc;
   unsigned long sectorCount;
   unsigned char flags;
   unsigned char writeProtect;
   unsigned char authenticated;
   unsigned short currentSector;
   unsigned char dosType;
};
typedef struct S_AtrFile AtrFile;
typedef AtrFile *AtrFilePtr;

struct S_HDR
{
unsigned char idLow, idHigh;
unsigned char paraLow, paraHigh;
unsigned char secSizeLow, secSizeHigh;
unsigned char paraHigher;
unsigned char crc1, crc2, crc3, crc4;
unsigned char unused1, unused2, unused3, unused4;
unsigned char flags;
} hdr;
typedef struct S_HDR AtrHeader;

typedef unsigned char byte;

unsigned char bootData[384] = {
      0x00, 0x03, 0x00, 0x07, 0x14, 0x07, 0x4C, 0x14,
      0x07, 0x00, 0x00, 0x00, 0x00, 0xA9, 0x46, 0x8D,
      0xC6, 0x02, 0xD0, 0xFE, 0xA0, 0x00, 0xA9, 0x6B,
      0x91, 0x58, 0x20, 0xD9, 0x07, 0xB0, 0xEE, 0x20,
      0xC4, 0x07, 0xAD, 0x7A, 0x08, 0x0D, 0x76, 0x08,
      0xD0, 0xE3, 0xA5, 0x80, 0x8D, 0xE0, 0x02, 0xA5,
      0x81, 0x8D, 0xE1, 0x02, 0xA9, 0x00, 0x8D, 0xE2,
      0x02, 0x8D, 0xE3, 0x02, 0x20, 0xEB, 0x07, 0xB0,
      0xCC, 0xA0, 0x00, 0x91, 0x80, 0xA5, 0x80, 0xC5,
      0x82, 0xD0, 0x06, 0xA5, 0x81, 0xC5, 0x83, 0xF0,
      0x08, 0xE6, 0x80, 0xD0, 0x02, 0xE6, 0x81, 0xD0,
      0xE3, 0xAD, 0x76, 0x08, 0xD0, 0xAF, 0xAD, 0xE2,
      0x02, 0x8D, 0x70, 0x07, 0x0D, 0xE3, 0x02, 0xF0,
      0x0E, 0xAD, 0xE3, 0x02, 0x8D, 0x71, 0x07, 0x20,
      0xFF, 0xFF, 0xAD, 0x7A, 0x08, 0xD0, 0x13, 0xA9,
      0x00, 0x8D, 0xE2, 0x02, 0x8D, 0xE3, 0x02, 0x20,
      0xAE, 0x07, 0xAD, 0x7A, 0x08, 0xD0, 0x03, 0x4C,
      0x3C, 0x07, 0xA9, 0x00, 0x85, 0x80, 0x85, 0x81,
      0x85, 0x82, 0x85, 0x83, 0xAD, 0xE0, 0x02, 0x85,
      0x0A, 0x85, 0x0C, 0xAD, 0xE1, 0x02, 0x85, 0x0B,
      0x85, 0x0D, 0xA9, 0x01, 0x85, 0x09, 0xA9, 0x00,
      0x8D, 0x44, 0x02, 0x6C, 0xE0, 0x02, 0x20, 0xEB,
      0x07, 0x85, 0x80, 0x20, 0xEB, 0x07, 0x85, 0x81,
      0xA5, 0x80, 0xC9, 0xFF, 0xD0, 0x10, 0xA5, 0x81,
      0xC9, 0xFF, 0xD0, 0x0A, 0x20, 0xEB, 0x07, 0x85,
      0x80, 0x20, 0xEB, 0x07, 0x85, 0x81, 0x20, 0xEB,
      0x07, 0x85, 0x82, 0x20, 0xEB, 0x07, 0x85, 0x83,
      0x60, 0x20, 0xEB, 0x07, 0xC9, 0xFF, 0xD0, 0x09,
      0x20, 0xEB, 0x07, 0xC9, 0xFF, 0xD0, 0x02, 0x18,
      0x60, 0x38, 0x60, 0xAD, 0x09, 0x07, 0x0D, 0x0A,
      0x07, 0x0D, 0x0B, 0x07, 0xF0, 0x79, 0xAC, 0x79,
      0x08, 0x10, 0x50, 0xEE, 0x77, 0x08, 0xD0, 0x03,
      0xEE, 0x78, 0x08, 0xA9, 0x31, 0x8D, 0x00, 0x03,
      0xA9, 0x01, 0x8D, 0x01, 0x03, 0xA9, 0x52, 0x8D,
      0x02, 0x03, 0xA9, 0x40, 0x8D, 0x03, 0x03, 0xA9,
      0x80, 0x8D, 0x04, 0x03, 0xA9, 0x08, 0x8D, 0x05,
      0x03, 0xA9, 0x1F, 0x8D, 0x06, 0x03, 0xA9, 0x80,
      0x8D, 0x08, 0x03, 0xA9, 0x00, 0x8D, 0x09, 0x03,
      0xAD, 0x77, 0x08, 0x8D, 0x0A, 0x03, 0xAD, 0x78,
      0x08, 0x8D, 0x0B, 0x03, 0x20, 0x59, 0xE4, 0xAD,
      0x03, 0x03, 0xC9, 0x02, 0xB0, 0x22, 0xA0, 0x00,
      0x8C, 0x79, 0x08, 0xB9, 0x80, 0x08, 0xAA, 0xAD,
      0x09, 0x07, 0xD0, 0x0B, 0xAD, 0x0A, 0x07, 0xD0,
      0x03, 0xCE, 0x0B, 0x07, 0xCE, 0x0A, 0x07, 0xCE,
      0x09, 0x07, 0xEE, 0x79, 0x08, 0x8A, 0x18, 0x60,
      0xA0, 0x01, 0x8C, 0x76, 0x08, 0x38, 0x60, 0xA0,
      0x01, 0x8C, 0x7A, 0x08, 0x38, 0x60, 0x00, 0x03,
      0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
   };

/* function prototypes */
int CreateBootAtr( char *atrName, char *fileName);
