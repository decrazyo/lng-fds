#ifndef _STDIO_H
#define _STDIO_H

#ifndef USING_CA65
#include <jumptab.h>
#else
#include <jumptab.ca65.h>
#endif

#include <fs.h>

#define stdin  0
#define stdout 1
#define stderr 2

#define fgetc  lkf_fgetc
#define fputc  lkf_fputc
#define fopen  lkf_fopen
#define fclose lkf_fclose
#define fcmd   lkf_fcmd
#define fopendir lkf_fopendir
#define freaddir lkf_freaddir

#endif
