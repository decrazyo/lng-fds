/* 6502/10 linker (lld) Version 0.08

   Written by Daniel Dallmann (aka Poldi) in Sep 1996.
   This piece of software is freeware ! So DO NOT sell it !!
   You may copy and redistribute this file for free, but only with this header
   unchanged in it. (Or you risc eternity in hell)

   If you've noticed a bug or created an additional feature, let me know.
   My (internet) email-address is dallmann@heilbronn.netsurf.de

   Sep 30 2001 *poldi*  fixed: open files in binary mode

   Nov 15 2000 *mouse*  added: appleii_mode, -a flag to toggle
			(don't write out two-byte header of start address)

   Feb 18 2000 *poldi*  -N : LNG mode operation

   Jun 9  1999 *poldi*  code cleaning

   Jun 8       *Stefan Haubenthal* AMIGA related patches

   Nov 1  1998 *poldi*  added: "-d file", output readable list of all
                               global labels and their value
   Jun 21 1997 *poldi*  added: environment variable that holds a list of
                               libraries that are included per default.
                        added: flag for quiet operation
                        fixed: duplicated global error message

   Jun 15 1997 *poldi*  fixed: bug in library creation code.

   Dec 15 1996 *poldi*  added support of LUnix-code

   ...
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#undef debug

#define USE_GETENV              /* use LLD_LIBRARIES to find libraries */

#ifdef _AMIGA
const char *VERsion="$VER: lld 0.08 "__AMIGADATE__" $";
#define PATH_SEPARATOR ','      /* character used as path separator  */
#else
#define PATH_SEPARATOR ':'      /* character used as path separator */
#endif

  /* export LLD_LIBRARIES=/usr/lib/c64:/usr/lib/lunix
                                     ^        ^ dir. separator
                               path separator

  NOTE: LLD_LIBRARIES  used for normal objectfiles
        LUNA_LIBRARIES used for lunix objectfiles
	LNG_LIBRARIES  used for normal objectfiles in LNG mode
  */

#define FILES_MAX 50        /* max number of files to link */
#define GLOBALS_MAX 500     /* max number of globals in an objectfile */
#define LABEL_LENGTH_MAX 40 /* max length of label-names */
#define LIB_NUM_MAX 4       /* max number of libraries to link against */
#define MOD_NUM_MAX FILES_MAX /* max number of objects in a library */

#define NOTHING (-1)

/* prototypes */

void make_lib(void);
void Howto(void);
void error(char*);
void derror(char*);
int search_global(char*);
void ill_object(char*);
void ill_library(char*);
int search_unknown(char*);
char *str_sav(char*);
void add_global(char*, int);
void add_unknown(char*);
int read_byte(FILE*, char*);
void write_byte(FILE*, unsigned char);
void make_code(int, int, char*);
FILE *open_ext(char*, unsigned int*);
void add_code(FILE*, char*, int);
void write_buffer(FILE*);

/* global variables */

static char *global[GLOBALS_MAX];
static char *unknown[GLOBALS_MAX];
static int  glob_val[GLOBALS_MAX];
static int  global_num;
static int  unknown_num;
static int  errors;
static char str[150];

static char *infile[FILES_MAX];
static int  infile_num;
static char *file_output;

static char  *code_buffer;
static int  code_buffer_ptr;
static int  code_buffer_length;
static int  quiet_mode;

void remove_unknown(int);

void error(char *text)
{
  printf("  error:%s\n",text);
  errors++;
}

void derror(char *text)
{
  printf("  panic:%s\n",text);
  exit(1);
}

int search_global(char *name)
{
  int i;

# ifdef debug
  printf("# search global \"%s\"\n",name);
# endif

  i=0;
  while (i<global_num) {
    if (!strcmp(global[i],name)) return i;
    i++; }

  return NOTHING;
}

void ill_object(char *name)
{
  sprintf(str,"%s: illegal object format",name);
  error(str);
  exit(1);
}

void ill_library(char *name)
{
  sprintf(str,"%s: illegal library format",name);
  error(str);
  exit(1);
}

int search_unknown(char *name)
{
  int i;

# ifdef debug
  printf("# search unknown \"%s\"\n",name);
# endif

  i=0;
  while (i<unknown_num) {
    if (!strcmp(unknown[i],name)) return i;
    i++; }

  return NOTHING;
}

void remove_unknown(int i)
{

# ifdef debug
  printf("# remove unknown \"%s\"\n",unknown[i]);
# endif

  free(unknown[i]);
  unknown_num--;
  while (i<unknown_num) {
    unknown[i]=unknown[i+1];
    i++; }
}

char *str_sav(char *string)
{
  char *tmpstr;

  tmpstr=(char*)malloc(strlen(string)+1);
  if (tmpstr==NULL) {
    error("out of memory");
    exit(1); }

  strcpy(tmpstr,string);
  return tmpstr;
}

void add_global(char *name,int val)
{
  int i;

# ifdef debug
  printf("# add global \"%s\"=%i\n",name,val);
# endif

  if (global_num>=GLOBALS_MAX) {
    error("too many globals");
    exit(1); }

  i=search_global(name);
  if (i!=NOTHING) {
    sprintf(str,"duplicated label \"%s\"",name);
    error(str);
    return; }

  i=search_unknown(name);
  if (i!=NOTHING) remove_unknown(i);

  global[global_num]=str_sav(name);
  glob_val[global_num]=val;
  global_num++;
}  

void add_unknown(char *name)
{
  int i;

# ifdef debug
  printf("# add unknown \"%s\"\n",name);
# endif

  if (unknown_num>=GLOBALS_MAX) {
    error("too many globals");
    exit(1); }

  i=search_unknown(name);
  if (i!=NOTHING) return;

  unknown[unknown_num]=str_sav(name);
  unknown_num++; 
}

int read_byte(FILE *stream, char *name)
{
  static int tmp;

  tmp=fgetc(stream);
  if (tmp==EOF) {
    sprintf(str,"unexpected EOF reading \"%s\"",name);
    error(str);
    exit(1); }

  return tmp;
}

void write_byte(FILE *stream, unsigned char byte)
{
  if (fputc(byte,stream)==EOF) {
    error("i/o-error while writing to outfile");
    exit(1); }
}

void make_code(int flags, int val, char *fname)
{
  if (code_buffer_ptr+2>=code_buffer_length) 
    printf("%i of %i !\n",code_buffer_ptr,code_buffer_length); /*ill_object(fname);*/

  if ((flags&0x03)==0x03) {
    /* put word */
    code_buffer[code_buffer_ptr++]=val & 0xff;
    code_buffer[code_buffer_ptr++]=(val>>8) & 0xff; }

  else if (flags&0x01) {
    /* only put low byte */
    code_buffer[code_buffer_ptr++]=val & 0xff; }

  else if (flags&0x02) {
    /* only put high byte */
    code_buffer[code_buffer_ptr++]=(val>>8)&0xff; }

  else ill_object(fname);

  return;
}

FILE *open_ext(char *file, unsigned int *size)
{
  FILE *inf;

  inf=fopen(file,"rb");
  if (inf==NULL) {
    sprintf(str,"can't open inputfile \"%s\"",file);
    error(str);
    exit(1); }

  read_byte(inf,file);
  read_byte(inf,file);
  read_byte(inf,file);

  /* skip globals */

  while (read_byte(inf,file)!=0) {
    while (read_byte(inf,file)!=0) ;
    read_byte(inf,file);
    read_byte(inf,file); }

  /* skip length of module-code */

  *size=read_byte(inf,file)+(read_byte(inf,file)<<8);

  return inf;
}

void make_lib()
{
  int f_num;
  FILE *outf, *inf;
  char *fname;
  int  tmp;
  unsigned int  size;

  outf=fopen(file_output,"wb");
  if (outf==NULL) {
    error("can't write to output-file");
    exit(1); }

  write_byte(outf,'l');
  write_byte(outf,'i');
  write_byte(outf,'b');

  f_num=0;
  while (f_num<infile_num) {
    fname=infile[f_num];

    inf=fopen(fname,"rb");
    if (inf==NULL) {
      sprintf(str,"can't open inputfile \"%s\"",infile[f_num]);
      error(str);
      exit(1); }

    tmp= (read_byte(inf,fname)!='o'); 
    tmp|=(read_byte(inf,fname)!='b');
    tmp|=(read_byte(inf,fname)!='j');
    if (tmp) ill_object(fname);

    /* add globals of module to archive */

    while ((tmp=read_byte(inf,fname))!=0) {
      write_byte(outf,tmp);
      while ((tmp=read_byte(inf,fname))!=0) write_byte(outf,tmp);
      write_byte(outf,0);
      write_byte(outf,read_byte(inf,fname));
      write_byte(outf,read_byte(inf,fname)); }
    write_byte(outf,0);

    /* add length of module-code */

    write_byte(outf,read_byte(inf,fname));
    write_byte(outf,read_byte(inf,fname));

    /* add externals of module */

    while ((tmp=read_byte(inf,fname))!=0) {
      write_byte(outf,tmp);
      while ((tmp=read_byte(inf,fname))!=0) write_byte(outf,tmp);
      write_byte(outf,0); }
    write_byte(outf,0);

    fclose(inf);
    f_num++; }

  write_byte(outf,1); /* end mark */

  f_num=0;
  while (f_num<infile_num) {
    fname=infile[f_num];

    inf=open_ext(fname,&size);

    /* skip externals of module */

    /* add externals of module a second time */

    while ((tmp=read_byte(inf,fname))!=0) {
      write_byte(outf,tmp);
      while ((tmp=read_byte(inf,fname))!=0) write_byte(outf,tmp);
      write_byte(outf,0); }
    write_byte(outf,0);

    /* add code of module to archive */

    while ((tmp=fgetc(inf))!=0) {
      write_byte(outf,tmp);
      if (tmp==0) {
        if (fgetc(inf)!=EOF) ill_object(fname);
	    break; }
      if (tmp<0x80) {
        while (tmp!=0) {
          write_byte(outf,read_byte(inf,fname));
          tmp--; } }
      else if (((tmp&0xf0)==0x80) || ((tmp&0xf0)==0xc0)) {
        write_byte(outf,read_byte(inf,fname));
        write_byte(outf,read_byte(inf,fname)); }
      else if ((tmp&0xf0)==0xd0) {
        write_byte(outf,read_byte(inf,fname));
        write_byte(outf,read_byte(inf,fname));
        write_byte(outf,read_byte(inf,fname));
        write_byte(outf,read_byte(inf,fname)); }
      else ill_object(fname);
	  }

    write_byte(outf,0);
    fclose(inf);
    if (!quiet_mode) printf("  \"%s\" added.\n",fname);
    f_num++; }
  if (!quiet_mode) printf("done.\n");
}

void add_code(FILE *inf, char *fname, int pc)
{
  int  tmp,i,j;
  int  lab_map[GLOBALS_MAX];
  int  map_size;
  char tmpname[LABEL_LENGTH_MAX];

  /* read list of externals and create remap-table */

  map_size=0;
  while ((tmp=read_byte(inf,fname))!=0) {
    j=1;
    tmpname[0]=tmp;
    while ((tmpname[j]=read_byte(inf,fname))!=0) j++;
    lab_map[map_size++]=search_global(tmpname); }

  /* relocate code */

# ifdef debug
  printf("adding code of \"%s\" at %i (bufferspace %i bytes)\n",fname,pc,code_buffer_length);
# endif


  while ((tmp=fgetc(inf))!=EOF) {
    if (tmp==0) {
      /* end of code mark */
      break; }
    else if (tmp<0x80) {
      /* code fragment without change */
      if (code_buffer_ptr+tmp>=code_buffer_length) 
        ill_object(fname);
      while (tmp!=0) {
        code_buffer[code_buffer_ptr++]=read_byte(inf,fname);
        tmp--; } }
    else if ((tmp&0xf0)==0x80) {
      /* normal relocation */
      i=read_byte(inf,fname)|(read_byte(inf,fname)<<8);
      make_code(tmp,i+pc,fname); }
    else if ((tmp&0xf0)==0xc0) {
      /* insert value of external */
      i=read_byte(inf,fname)|(read_byte(inf,fname)<<8);
      if (i<0 || i>map_size) {
        printf("no. of external out of range\n");
        ill_object(fname); }
      make_code(tmp,glob_val[lab_map[i]],fname); }
    else if ((tmp&0xf0)==0xd0) {
      /* insert modified value of external */
      i=read_byte(inf,fname)|(read_byte(inf,fname)<<8);
      j=read_byte(inf,fname)|(read_byte(inf,fname)<<8);
      if (j&0x8000) j-=0x10000;
      if (i<0 || i>map_size) {
        printf("no. of external out of range\n");
        ill_object(fname); }
      make_code(tmp,glob_val[lab_map[i]]+j,fname); }
    else {
      printf("prefix %i unknown\n",tmp);
      ill_object(fname); }
  }
}

void write_buffer(FILE *outf)
{
  int i;

# ifdef debug
  printf("writing buffer (%i/%i bytes)\n",code_buffer_ptr,code_buffer_length);
# endif  
  i=0;
  while (i<code_buffer_ptr) write_byte(outf,code_buffer[i++]);
  code_buffer_ptr=0;
}

void Howto()
{
  printf("lld [-dlLNaoqs] input-files...\n");
  printf("  linker for objectcode created by 'luna' 6502/10 assembler\n");
  printf("  this is version 0.08\n");
  printf("  -d file = dump list of all global addresses in file\n");
  printf("  -l library-file\n");
  printf("  -L = create library instead of executable\n");
  printf("  -N generate LNG binary\n");
  printf("  -a apple II mode - output raw binary (no 2-byte start adr header)\n");
  printf("  -o output-file (default is c64.out or c64.lib)\n");
  printf("  -q quiet operation\n");
  printf("  -s address (start address in decimals, default 4096)\n");
#ifdef USE_GETENV
  printf(" environment\n");
  printf("  LLD_LIBRARIES '%c' separated list of standard libraries\n",PATH_SEPARATOR);
  printf("  LUNIX_LIBRARIES same list but used in LUnix-mode\n");
  printf("  LNG_LIBRARIES same list but used in LNG-mode\n");
#endif
  exit(1);
}

int main(int argc, char **argv)
{
  int           i,j,flag,need_flag;
  unsigned int  pc;
  int           f_num;
  FILE          *inf;
  FILE          *outf;
  int           tmp;
  char          *fname;
  unsigned int  size;
  char          tmpname[LABEL_LENGTH_MAX];
  int           pc_start;
  int           pc_end;

  int           lib_flag;
  char          *lib[LIB_NUM_MAX];
  int           lib_num;
  int           *mod_flag[LIB_NUM_MAX];
  int           *lib_clen[LIB_NUM_MAX];
  int           lib_size[LIB_NUM_MAX];

  int           solved_flag;
  int           mod_num;
  int           *mod__flag;
  int           mod_cnt;
  int           lunix_mode;
  int           lng_mode;
  int		appleii_mode;

  char          *envtmp;
  char          *dump_file_name;

  lib_num=infile_num=errors=global_num=unknown_num=0;
  dump_file_name=0;
  pc=0x1000; /* default value, also for LUnix-executables */

  lunix_mode=quiet_mode=lng_mode=appleii_mode=0;
  i=1; lib_flag=0; j=0;
  while ( i<argc ) {
    if (argv[i][0]=='-') {
      j=1;
      while (argv[i][j]!='\0') {
        switch (argv[i][j]) {
		case 'a': { appleii_mode++; break; }
		case 'd': { i++; dump_file_name=argv[i]; j=0; break; }
		case 'o': { i++; file_output=argv[i]; j=0; break; }
		case 'L': { lib_flag=1; break; }
		case 'q': { quiet_mode=1; break; }
		case 'N': { lng_mode=1; break; }
		case 'l': {
		  i++;
		  if (lib_num>=LIB_NUM_MAX) {
			error("too many libraries");
			exit(1); }
		  lib[lib_num]=argv[i];
		  lib_num++;
		  j=0; break; }
		case 's': {
		  i++;
		  if (sscanf(argv[i],"%i",&pc)==0) Howto();
		  j=0; break; }
		default:  Howto();
		}
        if (i==argc) Howto();
        if (j==0) break;
        j++; }
	} else {
      if (infile_num>=FILES_MAX) {
        error("too many inputfiles");
        exit(1); }
      infile[infile_num]=argv[i];
      infile_num++; }
    i++; }

  if (infile_num==0) { printf("%s: No input file\n",argv[0]); exit(1); }

  if (file_output==NULL) {
    if (!lib_flag) file_output="c64.out";
    else file_output="c64.lib";
  }

  if (lib_flag) {
    if (lib_num!=0) {
      error("can't create library including libraries");
      exit(1); }
    make_lib();
    exit(0); }

  if (pc>0xffff) {
    error("illegal address");
    exit(1); }

  if (lng_mode && pc!=0x1000)
    error("LNG binaries have start address 0x1000");

  pc_start=pc;

  /* first built up database */

  f_num=0;
  while (f_num<infile_num) {
    fname=infile[f_num];

#   ifdef debug
    printf("# processing file \"%s\", pc=%i\n",fname,pc);
#   endif

    inf=fopen(fname,"rb");
    if (inf==NULL) {
      sprintf(str,"can't open inputfile \"%s\"",infile[f_num]);
      error(str);
      exit(1); }

    tmp= read_byte(inf,fname);
    if (tmp=='O') {
      lunix_mode=1;
      if ((pc & 0x00ff)!=0) {
        error("illegal address");
        exit(1); }
      tmp=0;
      if (lng_mode) error("can't generate LNG binary from LUnix object");
      if (f_num!=0) error("LUnix-object must be first file"); }
     else 
      tmp=(tmp!='o');
    tmp|=(read_byte(inf,fname)!='b');
    tmp|=(read_byte(inf,fname)!='j');
    if (tmp) ill_object(fname);
    
    /* read list of globals and their value */

    while ((tmp=read_byte(inf,fname))!=0) {
      j=1;
      tmpname[0]=tmp;
      while ((tmpname[j]=read_byte(inf,fname))!=0) {
        j++;
        if (j>=LABEL_LENGTH_MAX) {
          error("label too long");
          exit(1); } }
      tmp=read_byte(inf,fname)+(read_byte(inf,fname)<<8);
      add_global(tmpname,tmp+pc);
      }

     size=read_byte(inf,fname)+(read_byte(inf,fname)<<8);
     
#    ifdef debug
     printf("# size is %i\n",size);
#    endif

     /* read list of externals */

    while ((tmp=read_byte(inf,fname))!=0) {
      j=1;
      tmpname[0]=tmp;
      while ((tmpname[j]=read_byte(inf,fname))!=0) {
        j++;
        if (j>=LABEL_LENGTH_MAX) {
          error("label too long");
          exit(1); } }
      if (search_global(tmpname)==NOTHING) add_unknown(tmpname);
      }

    fclose(inf);
    
    pc+=size;
    if (pc>0xffff) {
      error("code crossed 64k border");
      exit(1); }

  f_num++; }

#ifdef USE_GETENV
  /* add librays specified by environment variable */

  if (lunix_mode)
    envtmp=getenv("LUNIX_LIBRARIES");
  else
    if (lng_mode)
      envtmp=getenv("LNG_LIBRARIES");
    else
      envtmp=getenv("LLD_LIBRARIES");
  
  if (envtmp!=NULL) {
    char *tmp_name;

    while (1) {
      i=0;
      while (envtmp[i]!='\0' && envtmp[i]!=PATH_SEPARATOR) i++;
      if (lib_num>=LIB_NUM_MAX) {
        error("too many libraries\n");
        exit(1); }
      tmp_name=(char*)malloc(sizeof(char)*(i+1));
      strncpy(tmp_name,envtmp,i);
      tmp_name[i]='\0';
      lib[lib_num++]=tmp_name;
      if (envtmp[i]!='\0') envtmp=&envtmp[i+1];
      else break; } }
#endif

  /* now get symbols from libraries */

  f_num=0;
  while (f_num<lib_num) {
    fname=lib[f_num];

#   ifdef debug
    printf("# processing library \"%s\", pc=%i\n",fname,pc);
#   endif

    /* find out what modules of this library must be included */

    mod__flag=(int*) malloc(sizeof(int)*MOD_NUM_MAX);
    lib_clen[f_num]=(int*) malloc(sizeof(int)*MOD_NUM_MAX);

    if (mod__flag==NULL || lib_clen[f_num]==NULL) {
      error("out of memory");
      exit(1); }

    mod_num=0; i=0;
    solved_flag=1;
    while (solved_flag) {
      solved_flag=0;

#     ifdef debug
      printf("\n# next pass... i=%i\n",i);
#     endif

      inf=fopen(fname,"rb");
      if (inf==NULL) {
        sprintf(str,"can't open library \"%s\"",fname);
        error(str);
        exit(1); }

      tmp= (read_byte(inf,fname)!='l'); 
      tmp|=(read_byte(inf,fname)!='i');
      tmp|=(read_byte(inf,fname)!='b');
      if (tmp) ill_library(fname);
    
      /* read list of globals and their value */

      mod_cnt=0;
      while ((tmp=read_byte(inf,fname))!=1) {
        if (i==0) {
          mod__flag[mod_num]=0;
          mod_num++; }
        flag=need_flag=0;
        while (tmp!=0) {
          j=1;
          tmpname[0]=tmp;
          while ((tmpname[j]=read_byte(inf,fname))!=0) {
            j++;
            if (j>=LABEL_LENGTH_MAX) {
            error("label too long");
            exit(1); } }
          tmp=read_byte(inf,fname)+(read_byte(inf,fname)<<8);
          if(search_unknown(tmpname)!=NOTHING) {
            need_flag=1;
            if (mod__flag[mod_cnt]==0) flag=1;
            if (i==-1)
              add_global(tmpname,pc+tmp); }
          else {
            if (i==-1 && search_global(tmpname)!=NOTHING) {
              char message[200];
              sprintf(message,"duplicated global \"%s\"",tmpname);
              error(message); }}
          tmp=read_byte(inf,fname); }
        tmp=read_byte(inf,fname)+(read_byte(inf,fname)<<8);
        lib_clen[f_num][mod_cnt]=tmp;
        if (i==-1 && need_flag) {
          pc+=tmp;
          if (pc>0xffff) {
            error("code crossed 64k border");
            exit(1); } }
        if (flag) {
          /* okay, we need this module, so add its unknowns ! */
#         ifdef debug
          printf("# need module %i\n",mod_cnt);
#         endif
          mod__flag[mod_cnt]=1;
          solved_flag=1;
          while ((tmp=read_byte(inf,fname))!=0) {
            j=1;
            tmpname[0]=tmp;
            while ((tmpname[j]=read_byte(inf,fname))!=0) {
              j++;
              if (j>=LABEL_LENGTH_MAX) {
              error("label too long");
              exit(1); } }
            if (search_global(tmpname)==NOTHING) add_unknown(tmpname); }
          }
        else {
          while (read_byte(inf,fname)!=0)
            while (read_byte(inf,fname)!=0) ; }

        mod_cnt++; }
      i++;
      if (!solved_flag) if (i!=0) { i=-1; solved_flag=1; }
	  }

    mod_flag[f_num]=mod__flag;
    lib_size[f_num]=mod_num;
    f_num++; }

  /* are there still unresolved labels ? ... */

# ifdef debug
  printf("\n");
# endif

  i=0;
  while (i<unknown_num) {
    sprintf(str,"undefined reference to \"%s\"",unknown[i]);
    error(str);
    i++; }

  if (errors) {
    printf("summary: %i error(s), linking stopped\n",errors);
    exit(1); }

# ifdef debug
  printf("# second pass...\n\n");
# endif

  outf=fopen(file_output,"wb");
  if (outf==NULL) {
    sprintf(str,"can't open outputfile \"%s\"",file_output);
    error(str); }

  pc_end=pc;
  pc=pc_start;
  if (lunix_mode) {
    write_byte(outf,0xff);
    write_byte(outf,0xff); /* put LUnix-magic $ffff */
/*    write_byte(outf,0xfe); */ /* put LNG-magic $fffe */
    pc_end++; /* have to add $02=endofcode-marker */ }
  else {
    if (lng_mode) {
      pc_end++; /* have to add $02=endofcode-marker */ }
    else {
      if( appleii_mode == 0 ) /* apple ii mode - don't write hdr *mouse* */
      {
        write_byte(outf,pc & 0xff);
        write_byte(outf,(pc>>8)&0xff); /* put start address */ }
    }
  }

  f_num=0;
  while (f_num<infile_num) {
    fname=infile[f_num];

#   ifdef debug
    printf("# processing file \"%s\", pc=%i\n",fname,pc);
#   endif

    inf=open_ext(fname,&size);

#   ifdef debug
    printf("# size is %i\n",size);
#   endif

    code_buffer_length=size+2;
    code_buffer=malloc( (size_t) code_buffer_length);

    if (code_buffer==NULL) derror("out of memory");

    add_code(inf,fname,pc);
    if (getc(inf)!=EOF) ill_object(fname);

/* this is obsolete ?!? (gpz) */
#if 1
    if (lunix_mode && f_num==0) {
      /* have to adapt something in the header ! */
      code_buffer[65]=pc_start>>8;
      code_buffer[2]=1+((pc_end-pc_start-1)>>8);
#     ifdef debug
      printf("  lunix base page = %i\n",code_buffer[65]);
      printf("  lunix code length = %i pages (%i bytes)\n",
	     code_buffer[2],pc_end-pc_start);
#     endif
    }
                   
    if (lng_mode && f_num==0) {
      /* have to adapt something in the header ! */
      code_buffer[5]=pc_start>>8;
      code_buffer[4]=((pc_end-pc_start+255)>>8);
#     ifdef debug
      printf("  lng base page = %i\n",code_buffer[5]);
      printf("  lng code length = %i pages (%i bytes)\n",
	     code_buffer[4],pc_end-pc_start);
#     endif
    }

#else

    if (lng_mode && f_num==0) {
      /* have to adapt something in the header ! */
      code_buffer[5-2]=pc_start>>8;
      code_buffer[4-2]=((pc_end-pc_start+255)>>8);
#     ifdef debug
      printf("  lng base page = %i\n",code_buffer[5-2]);
      printf("  lng code length = %i pages (%i bytes)\n",
	     code_buffer[4-2],pc_end-pc_start);
#     endif
    }

#endif

    write_buffer(outf);
    free(code_buffer);

    fclose(inf);

    pc+=size;

# ifdef debug
  printf("\n");
# endif

  f_num++; }

  /* include stuff from libraries */

  f_num=0;
  while (f_num<lib_num) {
    fname=lib[f_num];

#   ifdef debug
    printf("# processing library \"%s\", pc=%i\n",fname,pc);
#   endif

    inf=fopen(fname,"rb");
    if (inf==NULL) {
      sprintf(str,"can't open library \"%s\"",infile[f_num]);
      error(str);
      exit(1); }

    read_byte(inf,fname);
    read_byte(inf,fname);
    read_byte(inf,fname);
    
    /* skip big lib-header */

    while ((tmp=read_byte(inf,fname))!=1) {
      while (tmp!=0) {
        while (read_byte(inf,fname)!=0);
        read_byte(inf,fname);
        read_byte(inf,fname);
        tmp=read_byte(inf,fname); }
      read_byte(inf,fname);
      read_byte(inf,fname);
      while (read_byte(inf,fname)!=0)
        while (read_byte(inf,fname)!=0); }

    /* add modules we need */

    mod__flag=mod_flag[f_num];
    mod_cnt=0;
    while (mod_cnt<lib_size[f_num]) {
      if (mod__flag[mod_cnt]) {
        code_buffer_length=lib_clen[f_num][mod_cnt]+2;
#       ifdef debug
        printf("# including module %i at pc=%i, %i bytes\n",mod_cnt,pc,code_buffer_length);
#       endif
        code_buffer=malloc(code_buffer_length);
        if (code_buffer==NULL) derror("out of memory");
        add_code(inf,fname,pc);
        write_buffer(outf);
        free(code_buffer);
        pc+=lib_clen[f_num][mod_cnt]; }
      else {
        /* skip externals */
        while (read_byte(inf,fname)!=0)
          while (read_byte(inf,fname)!=0) ;
        /* skip code of module */
        while ((tmp=fgetc(inf))!=EOF) {
          if (tmp==0) break;
          if (tmp<0x80) {
            while (tmp!=0) {
              read_byte(inf,fname);
              tmp--; } }
          else if (((tmp&0xf0)==0x80) || ((tmp&0xf0)==0xc0)) {
            read_byte(inf,fname);
            read_byte(inf,fname); }
          else if ((tmp&0xf0)==0xd0) {
            read_byte(inf,fname);
            read_byte(inf,fname);
            read_byte(inf,fname);
            read_byte(inf,fname); }
          else ill_object(fname);
	      }
        if (tmp!=0) ill_library(fname); }
      mod_cnt++; }

    fclose(inf);
    free(mod__flag);
    free(lib_clen[f_num]);
    f_num++; }

  if (lunix_mode || lng_mode)
    write_byte(outf,0x02); /* add endofcode-marker */

  fclose(outf);
  if (!quiet_mode) printf("done, %i bytes of code\n",pc-pc_start);

  if (dump_file_name) {
	outf=fopen(dump_file_name,"w");
	if (!outf) {
	  sprintf(str,"can't open \"%s\" for writing",dump_file_name);
      derror(str);
	}
	i=0;
	while (i<global_num) {
	  fprintf(outf," %4x : %s\n",glob_val[i],global[i]);
	  i++; }
	fclose(outf);
  }

  exit(0);
}
