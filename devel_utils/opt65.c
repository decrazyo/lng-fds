/* Peephole-Optimzier V0.12

   Written by Daniel Dallmann (aka Poldi)
   This piece of software is freeware ! So DO NOT sell it !!
   You may copy and redistribute this file for free, but only with this header
   unchanged in it. (Or you risc eternity in hell)

   If you've noticed a bug or created an additional feature, let me know.
   My (internet) email-address is Daniel.Dallmann@studbox.uni-stuttgart.de
*/

#include <stdio.h>
#include <string.h>

#undef debug_parse
#undef debug_opti1
#undef debug_opti2
#undef debug

#ifdef debug
#  define dbmsg(par) printf(par)
#else
#  define dbmsg(par)
#  define op2msg(par)
#endif


#define line_len 100

/* define tokens */

#define reg_a  0x0001
#define reg_x  0x0002
#define reg_y  0x0004
#define reg_s  0x0008
#define flag_d 0x0010
#define flag_n 0x0020
#define flag_v 0x0040
#define flag_z 0x0080
#define flag_c 0x0100
#define flag_i 0x0200
#define mem    0x0400
#define imem   0x0800

#define isjmp  0x0001 /* set, if command may cause a jump */
#define fixed  0x0002 /* set, if command should NOT be removed NOR moved */
#define dupl   0x0004 /* if command makes sense if repeated 
                              eg. "sta xx, sta xx" doesn't make sense but 
                                  "inc xx, inc xx" makes sense           */
#define isinit 0x0008 /* set, if commad initializes some flags or reg_y  */

#define flag_nz    (flag_n|flag_z)
#define flag_nzc   (flag_n|flag_z|flag_c)
#define flag_arith (flag_nzc | flag_v)
#define reg_sr     (flag_arith | flag_d|flag_i)

#define valid_map (reg_a | reg_x | reg_y | reg_s | reg_sr)

/* define tok-structure */

typedef struct {
  char text[3];
  int  dep;
  int  mod;
  int  flags;  } com;

/* table of assembler commands and their attributes */

#define tok_num (56+1)
#define null_tok  (tok_num+1)
#define no_tok    (tok_num+2)

static com tok[tok_num]={

   /* Name , depends on.. , modifies...       , special flags */

    { "cmp", reg_a|mem    , flag_arith        , 0       },
    { "cpx", reg_x|mem    , flag_arith        , 0       },
    { "cpy", reg_y|mem    , flag_arith        , 0       },

	{ "bit", reg_a|mem    , flag_nzc|flag_v   , fixed   },

	{ "bcc", flag_c       , 0                 , isjmp   },
	{ "bcs", flag_c       , 0                 , isjmp   },
	{ "beq", flag_z       , 0                 , isjmp   },
	{ "bne", flag_z       , 0                 , isjmp   },
	{ "bmi", flag_n       , 0                 , isjmp   },
	{ "bpl", flag_n       , 0                 , isjmp   },
	{ "bvc", flag_v       , 0                 , isjmp   },
    { "bvs", flag_v       , 0                 , isjmp   },

    { "jmp", mem          , 0                 , isjmp   },
    { "jsr", reg_s|mem    , reg_s|mem         , isjmp   },

    { "asl", reg_a|mem        , reg_a|flag_nzc|mem    , dupl    },
    { "lsr", reg_a|mem        , reg_a|flag_nzc|mem    , dupl    },
    { "rol", reg_a|flag_c|mem , reg_a|flag_nzc|mem    , dupl    },
    { "ror", reg_a|flag_c|mem , reg_a|flag_nzc|mem    , dupl    },

    { "clc", 0            , flag_c            , isinit  },
    { "cld", 0            , flag_d            , isinit   },
    { "cli", 0            , flag_i            , fixed   },
    { "clv", 0            , flag_v            , isinit   },
    { "sec", 0            , flag_c            , isinit   },
    { "sed", 0            , flag_d            , isinit   },
	{ "sei", 0            , flag_i            , fixed   },

	{ "nop", 0            , 0                 , fixed   },

    { "rts", reg_s|mem    , reg_s             , isjmp   },
	{ "rti", reg_s|mem    , reg_s|reg_sr      , isjmp   },
	{ "brk", 0            , reg_s|reg_sr|mem  , isjmp   },

    { "lda", mem          , reg_a|flag_nz     , 0       },
	{ "ldx", mem          , reg_x|flag_nz     , 0       },
	{ "ldy", mem          , reg_y|flag_nz     , isinit  },

    { "sta", reg_a        , mem               , 0       },
	{ "stx", reg_x        , mem               , 0       },
	{ "sty", reg_y        , mem               , 0       },

    { "tax", reg_a        , reg_x|flag_nz     , 0       },
	{ "tay", reg_a        , reg_y|flag_nz     , isinit  },
	{ "txa", reg_x        , reg_a|flag_nz     , 0       },
	{ "tya", reg_y        , reg_a|flag_nz     , 0       },
	{ "txs", reg_x        , reg_s|flag_nz     , 0       },
	{ "tsx", reg_s        , reg_x|flag_nz     , 0       },

	{ "pla", reg_s|mem    , reg_a|reg_s|flag_nz , dupl  },
	{ "plp", reg_s|mem    , reg_sr|reg_s      , dupl    },
	{ "pha", reg_a|reg_s  , reg_s|mem         , dupl    },
	{ "php", reg_sr|reg_s , reg_s|mem         , dupl    },

    { "adc", reg_a|flag_c|flag_d|mem , reg_a|flag_arith  , dupl },
	{ "sbc", reg_a|flag_c|flag_d|mem , reg_a|flag_arith  , dupl },

	{ "inc", mem          , mem|flag_nz       , dupl    },
	{ "dec", mem          , mem|flag_nz       , dupl    },
    { "inx", reg_x        , reg_x|flag_nz     , dupl    },
	{ "dex", reg_x        , reg_x|flag_nz     , dupl    },
	{ "iny", reg_y        , reg_y|flag_nz     , dupl|isinit    },
	{ "dey", reg_y        , reg_y|flag_nz     , dupl|isinit    },

    { "and", reg_a|mem        , reg_a|flag_nz     , 0       },
	{ "ora", reg_a|mem        , reg_a|flag_nz     , 0       },
	{ "eor", reg_a|mem        , reg_a|flag_nz     , 0       },

    /* pseudo-operators */

    { "equ", 0            , 0                 , 0       },

  };

#define  as_cmp 0
#define  as_cpx 1
#define  as_cpy 2
#define  as_bit 3
#define  as_bcc 4
#define  as_bcs 5
#define  as_beq 6
#define  as_bne 7
#define  as_bmi 8
#define  as_bpl 9
#define  as_bvc 10
#define  as_bvs 11
#define  as_jmp 12
#define  as_jsr 13
#define  as_asl 14
#define  as_lsr 15
#define  as_rol 16
#define  as_ror 17
#define  as_clc 18
#define  as_cld 19
#define  as_cli 20
#define  as_clv 21
#define  as_sec 22
#define  as_sed 23
#define  as_sei 24
#define  as_nop 25
#define  as_rts 26
#define  as_rti 27
#define  as_brk 28
#define  as_lda 29
#define  as_ldx 30
#define  as_ldy 31
#define  as_sta 32
#define  as_stx 33
#define  as_sty 34
#define  as_tax 35
#define  as_tay 36
#define  as_txa 37
#define  as_tya 38
#define  as_txs 39
#define  as_tsx 40
#define  as_pla 41
#define  as_plp 42
#define  as_pha 43
#define  as_php 44
#define  as_adc 45
#define  as_sbc 46
#define  as_inc 47
#define  as_dec 48
#define  as_inx 49
#define  as_dex 50
#define  as_iny 51
#define  as_dey 52
#define  as_and 53
#define  as_ora 54
#define  as_eor 55

typedef struct {
  int   tok;    /* token of assembler-command     */
  int   dep;    /* command's result depends on... */
  int   mod;    /* command modifies ...           */
  int   depind; /* indirect depentencies          */
  int   flags;  /* special command-flags          */
  int   feeds;  /* command is used to calculate.. */ 
  int   passes; /* things that are unchanged and used later */
  int   par;    /* command parameter              */
  int   mpar;   /* memory-address of dep or mod   */
  int   mparhi; /* high-byte if indirect addressed*/
  } line;

#define blkbuf_max 500  /* max blocksize of 500 lines should do the job */

static line blkbuf[blkbuf_max];
static int  blkbuf_len;

#define par_max 200     /* max 200 different parameter should be enough */
#define par_length 10   /* just an average */
#define no_par (par_max+1)

static int  par_num;
static int  par_pos[par_max];
static int  par_used;
static char parbuf[par_length*par_max];

static char mparbuf[par_length*par_max];
static int  mpar_used;
static int  mpar_num;
static int  mpar_pos[par_max];

#define direct 0x0001
#define indirect 0x0002
#define xindexed 0x0004
#define yindexed 0x0008
#define absolute 0x2000 /* set, if there is a known immediate value      */

static int  mpar_flag[par_max];
#define undefd 0x0100

static int  blk_mod;

static int  com_match_lnum;
static line *com_match_lptr;
static int test_match;

static char tmpstr[100];

static int  opt;
static int  inp_line;
static int  was_line;

char *getexpr(char *a, unsigned int *par);

/*********************************************************************/

void how_to()
{
  printf("usage: opt65 file\n");
  printf("  \"opt65\" is a peephole optimizer for 6502/10-assembler\n");
  printf("  sources. The optimized code is printed to stdout.\n");
  printf("  (This is version 0.12, Aug 23 1996, by 'Poldi')\n");
  exit(1);
}

void ill_format()
{
  printf("illegal file-format\n");
  exit(1);
}

int readline(char *buf, FILE *infile)
{
  static int x;
  inp_line++;
  x=0;
  while (x<line_len-1) {
    buf[x]=fgetc(infile);
    if (buf[x]=='\n'||buf[x]=='\0'||buf[x]==EOF) break;
    x++; }
  if (x==0 && buf[x]==EOF) return EOF;
  buf[x]='\0';
  return 0;
}    

void clear_buf()
{
  dbmsg("clearing buffer...\n");

  par_used=0;
  par_num=0;

  mpar_used=0;
  mpar_num=0;
}

/*********************************************************************/

#ifdef debug

void mapout(int map)
{
  if ( (map&reg_a )!=0 ) printf("A"); else printf("-");
  if ( (map&reg_x )!=0 ) printf("X"); else printf("-");
  if ( (map&reg_y )!=0 ) printf("Y"); else printf("-");
  if ( (map&reg_s )!=0 ) printf("S"); else printf("-");
  if ( (map&mem   )!=0 ) printf("M"); else printf("-");
  if ( (map&flag_n)!=0 ) printf("n"); else printf("-");
  if ( (map&flag_z)!=0 ) printf("z"); else printf("-");
  if ( (map&flag_c)!=0 ) printf("c"); else printf("-");
  if ( (map&flag_v)!=0 ) printf("v"); else printf("-");
  if ( (map&flag_d)!=0 ) printf("d"); else printf("-");
  if ( (map&flag_i)!=0 ) printf("i"); else printf("-");
}

void lineout(line *p)
{
  if ( p->tok==no_tok ) printf("???");
  else if ( p->tok==null_tok ) printf("---");
  else printf("%s",tok[p->tok].text);
  printf(" dep:");
   mapout(p->dep);
  printf(" mod:");
   mapout(p->mod);
  printf(" feeds:");
   mapout(p->feeds);
  printf(" passes:");
   mapout(p->passes);
  printf(" fl:%2i",p->flags);
  if (p->par!=no_par) {
    printf(" \"%s\"  [%i",&parbuf[par_pos[p->par]],p->par);
    if (p->depind & mem) {
      printf("/%i",p->mpar);
      if (p->depind&imem ) printf(",%i",p->mparhi);
      if (p->depind&reg_x) printf("Ix");
      if (p->depind&reg_y) printf("Iy"); }
    printf("]");
    if (p->depind&absolute) printf(", val=%i",p->mpar); }
  printf("\n");
}

void op2msg(char *a)
{
  if (test_match) printf("### "); else printf("*** ");
  printf("%s",a);
}          
#else

#define mapout(x)
#define op2msg(x)

#endif

void bufout()
{
  /* print block buffer */

  int i;

  i=0;
  while (i<blkbuf_len) {
    printf("\t %s",tok[blkbuf[i].tok].text);
    if (blkbuf[i].par!=no_par) {
      printf(" %s\n",&parbuf[par_pos[blkbuf[i].par]]); }
    else printf("\n");
    i++; }
}

/*********************************************************************/

int get_parid( char *par, int length)
{
  int x,y;

  y=0;
  x=0;
  while (x<par_num) {
    y=0;
    if (parbuf[par_pos[x]+length]!='\0') {
      x++;
      continue; }    
    while (y<length) {
      if (parbuf[par_pos[x]+y]!=par[y]) {
        y=0;
        break; }
      y++; }
    if (y!=0) break;
    x++; }

# ifdef debug_parse
  if (y!=0) printf(", equal to par[%i]\n",x);
# endif

  if (y==0) {

    /* never seen this parameter before (in this block) so add it to list */

#   ifdef debug_parse
    printf(", added to database par[%i]\n",par_num);
#   endif
    y=0;
    while (y<length) { 
      parbuf[par_used+y]=par[y];
      y++; }
    parbuf[par_used+y]='\0';

    par_pos[par_num]=par_used;
    par_used=par_used+length+1;
    x=par_num;
    par_num=par_num+1; }

  return x;
}

int get_mparid( char *mpar, int length )
{
  static int x,y;

  y=0;
  x=0;
  while (x<mpar_num) {
    y=0;
    if (mparbuf[mpar_pos[x]+length]!='\0') {
      x++;
      continue; }    
    while (y<length) {
      if (mparbuf[mpar_pos[x]+y]!=mpar[y]) {
        y=0;
        break; }
      y++; }
    if (y!=0) break;
    x++; }
    
# ifdef debug_parse
  if (y!=0) printf("existing mpar[%i]",x);
# endif

  if (y==0) {

    /* never seen this address before (in this block) so add it to list */

#   ifdef debug_parse
    printf("new mpar[%i]",mpar_num);
#   endif

    y=0;
    while (y<length) {
      mparbuf[mpar_used+y]=mpar[y];
      y++; }
    mparbuf[mpar_used+y]='\0';

    mpar_pos[mpar_num]=mpar_used;
    mpar_used=mpar_used+length+1;
    x=mpar_num;
    mpar_num++; }

# ifdef debug_parse
  printf(":%s\n",&mparbuf[mpar_pos[x]]);
# endif

  return x; 
}

/*********************************************************************/

int is_sep(int c)
{
  if (c>='0' && c<='9') return 0;
  if (c>='a' && c<='z') return 0;
  if (c>='A' && c<='Z') return 0;
  if (c=='_') return 0;
  if (c=='.') return 0;
  return 1;
}

int nextchar(char *a, int i)
{
  while ( a[i]==' ' || a[i]=='\t' ) i++;
  return i;
}

char *getval(char *a, unsigned int *par)
{
  static int i,cnt;
  static unsigned int val;

  cnt=0;
  *par=0;
  i=0;

  if (a[i]=='#' || (a[i]>='0' && a[i]<='9')) {
    /* get decimal value */
    if (a[i]=='#') i=nextchar(a,i);
    while (!is_sep(a[i])) {
      if (a[i]>='0' && a[i]<='9') val=a[i]-'0';
      else return NULL;
      *par=*par*10+val;
      cnt=cnt+1;
      i=i+1; }
    if (cnt==0) return NULL;
    return &a[i]; }

  if (a[i]=='$') {
    /* get hex value */
    i=nextchar(a,i+1);
    while (!is_sep(a[i])) {
      if (a[i]>='0' && a[i]<='9') val=a[i]-'0';
      else if (a[i]>='a' && a[i]<='f') val=a[i]-'a'+10;
      else return NULL;
      *par=*par*16+val;
      cnt=cnt+1;
      i=i+1; }
    if (cnt==0) return NULL;
    return &a[i]; }

  if (a[i]=='%') {
    /* get binary value */
    i=nextchar(a,i+1);
    while (!is_sep(a[i])) {
      if (a[i]=='0') val=0;
      else if (a[i]=='1') val=1;
      else return NULL;
      *par=*par*2+val;
      cnt=cnt+1;
      i=i+1; }
    if (cnt==0) return NULL;
    return &a[i]; }

  /* nothing of the obove, so it must be a label */
  /* i can't resolve label-values, sorry ! */

  return NULL;
}


char *getterm(char *a, unsigned int *par)
{

  if (*a=='<') {
    /* take lowbyte of term */
    a=getterm(&a[1], par);
    if (*par>0xffff) return NULL;
    *par=*par&255;
    return a; }

  if (*a=='>') {
    /* take highbyte of term */
    a=getterm(&a[1], par);
    if (*par>0xffff) return NULL;
    *par=(*par>>8)&255;
    return a; }

  if (*a=='(') {
    a=getexpr(&a[1], par);
    if (a==NULL) return NULL;
    a=&a[nextchar(a,0)];
    if (*a!=')') return NULL;
    return &a[1]; } 
  else 
    return getval(a, par);
}

char *getexpr(char *a, unsigned int *par)
{
  unsigned int tmp;

  a=getterm(a, par);
  if (a==NULL) return NULL;

  while (1) {

    if (*a=='+') {
      tmp=*par;
      a=getterm(&a[1], par);
      if (a==NULL) return NULL;
      *par=*par+tmp;
      continue; }

    if (*a=='-') {
      tmp=*par;
      a=getterm(&a[1], par);
      if (a==NULL) return NULL;
      *par=tmp-*par;
      continue; }

    if (*a=='*') {
      tmp=*par;
      a=getterm(&a[1], par);
      if (a==NULL) return NULL;
      *par=tmp* *par;
      continue; }

    if (*a=='/') {
      tmp=*par;
      a=getterm(&a[1], par);
      if (a==NULL) return NULL;
      *par=tmp/(*par);
      continue; }

    break; }

  return a;
}

/*********************************************************************/

int resolve_abs(char *a)
{
  static unsigned int tmp;

# ifdef debug_parse
  printf("try to resolve \"%s\", ",a);
# endif
   
  if (getexpr(a, &tmp)==NULL) { dbmsg("sorry\n"); return undefd; }
  if (tmp>0xff) { dbmsg("sorry >255\n"); return undefd; }
  else { 
#   ifdef debug_parse
    printf("value is %i\n",tmp);
#   endif
    return tmp; }
}

/* parse_line returns a value unequal to zero, if line includes
   a label-definition */

int parse_line(char *a, line *p)
{
  static int i,j,x,y;

  p->tok=null_tok;
  p->dep=0;
  p->mod=0;
  p->feeds=0;
  p->passes=0;
  p->depind=0;
  p->flags=0;
  p->mpar=0;
  p->mparhi=0;
  p->par=no_par;

# ifdef debug_parse
  printf("line=\"%s\"\n",a);
# endif

  /* remove leading white_spaces */

  i=nextchar(a,0);
  if (a[i]=='\0') return 0;
  if (a[i]==';' ) return 0;

  /* check for assembler-command */

  j=0;
  while (j<tok_num &&
          !(   a[i  ]==tok[j].text[0]
            && a[i+1]==tok[j].text[1]
            && a[i+2]==tok[j].text[2] ) ) j++;
  if (j==tok_num) {
    while (a[i]!=' ' && a[i]!='\t' && a[i]!='\0') i++;
    x=parse_line(&a[i], p);
    if (x!=0) return 2;
    return 1; }

  /* check for addressing mode */

  p->tok=j;
  p->dep=tok[j].dep;
  p->mod=tok[j].mod;
  p->flags=tok[j].flags;
  p->par=no_par;

  i=nextchar(a,i+3);
  if ( a[i]=='\0' || a[i]==';' ) return 0;
 
  /* hey, there seem to be a parameter */
  /* let's remove comments and white spaces */

  j=i;
  while (a[j]!='\0' && a[j]!=';') j++; /* search end of parameter */
  while (j>i) {
    if (a[j-1]!=' ' && a[j-1]!='\t') break;
    j=j-1; }
  j=j-i;

# ifdef debug_parse
  a[i+j]='\0';
  printf("par is \"%s\"",&a[i]);
# endif

  /* now i points to start and j is length of parameter-string */

  p->par=x=get_parid(&a[i],j);
  
  if (j==1 && (a[i]=='a'||a[i]=='A') ) return 0; /* Akku addressed */
  if (a[i]=='#') { /* immediate */
    if ( (p->mpar=resolve_abs(&parbuf[par_pos[x]+1]))!=undefd ) 
      p->depind|=absolute; /* resolved */
    return 0; }

  if ( a[i]=='(' ) { 
    i++;
    while ( a[i]==' ' || a[i]=='\t' ) i++; 
    p->depind=p->depind|imem; /* indirect-flag */ }

  p->depind=p->depind|mem;

  j=i;
  while ( a[j]!='\0' && a[j]!=';' && a[j]!=',' && a[j]!=')' 
                     && a[j]!=' ' && a[j]!='\t' ) j++;
  j=j-i;

  /* now "i" exactly points to start of mem-address, j is length */
  
  x=get_mparid( &a[i], j );
  p->mpar=x;

  if (p->depind & imem) {
    /* address points to 16bit-pointer */
    strcpy(tmpstr,&a[i]);
    tmpstr[j]='+';
    tmpstr[j+1]='1';
    p->mparhi=get_mparid( tmpstr, j+2 ); }

  i=i+j;

  /* scan for ",x" and ",y" idexes */  
    
  x=0;
  while (1) {
    if (a[i]=='\0'||a[i]==';') break;
    if (a[i]==' '||a[i]=='\t') { i++; continue; }
    if (a[i]==',')  { x=1; i++; continue; }
    if (a[i]=='x' && x==1) { x=2; i++; continue; }
    if (a[i]=='y' && x==1) { x=3; i++; continue; }
    x=0; i++; }

  if (x==2) {
    p->dep=p->dep|reg_x;
    p->depind=p->depind|reg_x;
  }
  if (x==3) {
    p->dep=p->dep|reg_y;
    p->depind=p->depind|reg_y;
  }
  return 0;
}

/*********************************************************************/

void line_copy(line *to, line *from)
{
  to->tok    =from->tok;
  to->dep    =from->dep;
  to->mod    =from->mod;
  to->flags  =from->flags;
  to->feeds  =from->feeds;
  to->passes =from->passes;
  to->depind =from->depind;
  to->par    =from->par;
  to->mpar   =from->mpar;
  to->mparhi =from->mparhi;
}

#define iline_copy(par1,par2)  line_copy(&blkbuf[par1],&blkbuf[par2])
  
/*********************************************************************/

void make_feedlist()
{
  static int hlp;
  static int i;
  static line *p;

  dbmsg("making feedlist...\n");

  hlp=blk_mod;
  if (blkbuf_len<1) return;
  i=0;
  while (i<mpar_num) mpar_flag[i++]=1;

  i=blkbuf_len-1;
  while( i>=0 ) {
    p=&blkbuf[i];
    p->feeds=p->mod & hlp;
    p->passes=hlp & ~p->mod;
    hlp=(hlp & ( ~p->mod )) | p->dep & valid_map;

    if (p->depind & mem) { 

      if (p->depind & imem) {

        /* command depends/modifies memory through a 16bit pointer*/
        /* don't now how to handle, so always set feed-flag */

        if (p->mod & mem) p->feeds|=mem;

        /* dep: ptr,ptr+1 */
 
        mpar_flag[p->mpar]=1;
        mpar_flag[p->mparhi]=1; }

      else if (p->depind & (reg_x|reg_y) ) {
      
        /* indexed addressmode (,x or ,y) */
        /* don't know the exact address, so always set feed-flag */

        if (p->mod & mem) p->feeds|=mem;

        /* dep: ptr */

        mpar_flag[p->mpar]=1; }

      else
  
        /* normal addressed memory (direct) */

        if ( mpar_flag[p->mpar] ) {
          if ((p->mod & mem)!=0) {
            p->feeds|=mem;
            mpar_flag[p->mpar]=0; }
          else p->passes|=mem; }

        if (p->dep & mem) {
          mpar_flag[p->mpar]=1; } }

    i--; }
}

/*********************************************************************/

int simple_erase()
{
  /* erase all commands, that don't feed a register/flag nor change memory 
     nor are fixed */

  int i,j;

  i=0; j=0;
  while (i<blkbuf_len) {
    if (blkbuf[i].feeds==0 && (blkbuf[i].flags&fixed)==0) {
      /* erase it ! */
#     ifdef debug
      printf("*** simple_erased: buf[%i]\n",i);
#     endif
      opt++;
      i++;
      continue; }
    if (i!=j) line_copy(&blkbuf[j],&blkbuf[i]);
    i++; j++; }

  blkbuf_len=j;
  return (i!=j);
}

/*********************************************************************/

void set_absval(line *p, int val)
{
  static char par[5];
  
  sprintf(par,"#%i",val);

  p->par=get_parid(par, strlen(par));
  p->depind=absolute;
}

int opti1()
{
  /* do some clean up */

  line *p;
  int i,j,val,done;
  int rega;
  int regx;
  int regy;
  int *par;
  int flag;

  rega=regx=regy=undefd;
  i=0; j=0; flag=0;
  while (i<mpar_num) mpar_flag[i++]=undefd;

  i=0;
  while (i<blkbuf_len) {
    p=&blkbuf[i];
    done=0;

    if (p->par!=no_par && (p->depind&mem)==0) { /* mem=0 so its # or a */
      if (p->depind&absolute) val=p->mpar; else val=undefd;

      switch (p->tok) {

	    case as_lda: { 
          if (rega==val && val!=undefd && (p->feeds&reg_sr)==0) {
#           ifdef debug_opti1
            printf("*** %i redundant lda#\n",i);
#           endif
            done=2; }
          else done=1;
          rega=val; 
          break; } 

        case as_ldx: { 
          if (regx==val && val!=undefd && (p->feeds&reg_sr)==0) {
#           ifdef debug_opti1
            printf("*** %i redundant ldx#\n",i);
#           endif
            done=2; }
          else done=1;
          regx=val; 
          break; }

        case as_ldy: { 
          if (regy==val && val!=undefd && (p->feeds&reg_sr)==0) {
#           ifdef debug_opti1
            printf("*** %i redundant ldy#\n",i);
#           endif
            done=2; }
          else done=1; 
          regy=val; 
          break; }

        case as_and: { 
          if ( (val!=undefd && rega!=undefd) || val==0 || rega==0 ) {
            rega&=val;
#           ifdef debug_opti1
            printf("### %i known and#-result #%i\n", i, rega);
#           endif
            /* replace "and #nn" with "lda #" */
            set_absval(p,rega);
            p->tok=as_lda;
            p->dep=tok[as_lda].dep; p->flags=tok[as_lda].flags;
            flag=done=1; }
          else {
            if ( (val==0xff) && (p->feeds&reg_sr)==0 ) {
#             ifdef debug_opti1
              printf("*** %i redundant and#\n",i);
#             endif
              done=2; }
            else done=1;
            rega=undefd; }
          break; }

        case as_ora: { 
          if ( (val!=undefd && rega!=undefd) || val==0xff || rega==0xff ) {
            rega|=val;
#           ifdef debug_opti1
            printf("### %i known ora#-result #%i\n", i, rega);
#           endif
            /* replace "ora #nn" with "lda #" */
            set_absval(p,rega);
            p->tok=as_lda;
            p->dep=tok[as_lda].dep; p->flags=tok[as_lda].flags;
            flag=done=1; }
          else {
            if ( (val==0) && (p->feeds&reg_sr)==0 ) {
#             ifdef debug_opti1
              printf("*** %i redundant ora#\n",i);
#             endif
              done=2; }
            else done=1;
            rega=undefd; }
          break; }

        case as_eor: { 
          if ( val!=undefd && rega!=undefd ) {
            rega^=val;
#           ifdef debug_opti1
            printf("### %i known eor#-result #%i\n", i, rega);
#           endif
            /* replace "eor #nn" with "lda #" */
            set_absval(p,rega);
            p->tok=as_lda;
            p->dep=tok[as_lda].dep; p->flags=tok[as_lda].flags;
            flag=done=1; }
          else {
            if ( (val==0) && (p->feeds&reg_sr)==0 ) {
#             ifdef debug_opti1
              printf("*** %i redundant eor#\n",i);
#             endif
              done=2; }
            else done=1;
            rega=undefd; }
          break; }
      }
	}

    if ( (p->depind & (mem|imem|reg_x|reg_y))==mem ) {
      par=&mpar_flag[p->mpar];

      switch (p->tok) {

	    case as_sta: { 
          if (*par==rega && rega!=undefd) {
#           ifdef debug_opti1
            printf("*** %i redundant sta\n",i);
#           endif
            done=2; }
          else done=1;
          *par=rega; 
          break; }

	    case as_stx: { 
          if (*par==regx && regx!=undefd) {
#           ifdef debug_opti1
            printf("*** %i redundant stx\n",i);
#           endif
            done=2; }
          else done=1;
          *par=regx; 
          break; }

	    case as_sty: { 
          if (*par==regy && regy!=undefd) {
#           ifdef debug_opti1
            printf("*** %i redundant sty\n",i);
#           endif
            done=2; }
          else done=1;
          *par=regy; 
          break; }

        case as_inc: { if (*par!=undefd) *par=0xff&(*par+1); done=1; break; }

        case as_dec: { if (*par!=undefd) *par=0xff&(*par-1); done=1; break; }

        case as_and: { 
          if ( (*par!=undefd && rega!=undefd) || *par==0 || rega==0 ) {
            rega&=*par;
#           ifdef debug_opti1
            printf("*** %i known and-result #%i\n", i, rega);
#           endif
            /* replace "and adr" with "lda #" */
            set_absval(p,rega);
            p->tok=as_lda;
            p->dep=tok[as_lda].dep; p->flags=tok[as_lda].flags;
            opt++;
            flag=done=1; }
          else {
            if ( *par==0xff && (p->feeds&reg_sr)==0 ) {
#             ifdef debug_opti1
              printf("*** %i redundant and\n",i);
#             endif
              done=2; }
            else 
              if ( *par!=undefd ) {
#               ifdef debug_opti1
                printf("*** %i known par #%i of and\n",i,*par);
#               endif
                /* replace "and adr" with "and #" */
                set_absval(p,*par);
                opt++;
                flag=done=1; }
            rega=undefd; }
          break; }

        case as_ora: { 
          if ( (*par!=undefd && rega!=undefd) || *par==0xff || rega==0xff ) {
            rega|=*par;
#           ifdef debug_opti1
            printf("*** %i known ora-result #%i\n", i, rega);
#           endif
            /* replace "ora adr" with "lda #" */
            set_absval(p,rega);
            p->tok=as_lda;
            p->dep=tok[as_lda].dep; p->flags=tok[as_lda].flags;
            opt++;
            flag=done=1; }
          else {
            if ( (*par==0) && (p->feeds&reg_sr)==0 ) {
#             ifdef debug_opti1
              printf("*** %i redundant ora\n",i);
#             endif
              done=2; }
            else 
              if ( *par!=undefd ) {
#               ifdef debug_opti1
                printf("*** %i known par #%i of ora\n",i,*par);
#               endif
                /* replace "ora adr" with "ora #" */
                set_absval(p,*par);
                opt++;
                flag=done=1; }
            rega=undefd; }
          break; }

        case as_eor: { 
          if ( *par!=undefd && rega!=undefd ) {
            rega^=*par;
#           ifdef debug_opti1
            printf("*** %i known eor-result #%i\n", i, rega);
#           endif
            /* replace "eor adr" with "lda #" */
            set_absval(p,rega);
            p->tok=as_lda;
            p->dep=tok[as_lda].dep; p->flags=tok[as_lda].flags;
            opt++;
            flag=done=1; }
          else {
            if ( (*par==0) && (p->feeds&reg_sr)==0 ) {
#             ifdef debug_opti1
              printf("*** %i redundant eor\n",i);
#             endif
              done=2; }
            else 
              if ( *par!=undefd ) {
#               ifdef debug_opti1
                printf("*** %i known par #%i of eor\n",i,*par);
#               endif
                /* replace "eor adr" with "eor #" */
                set_absval(p,*par);
                opt++;
                flag=done=1; }
            rega=undefd; }
          break; }

        case as_lda: {
          if (*par!=undefd) {
#           ifdef debug_opti1
            printf("*** %i lda #%i\n",i,*par);
#           endif
            /* replace "lda adr" with "lda #" */
            set_absval(p,*par);
            flag=1;
            opt++; }
          rega=*par;
          done=1; 
          break; }

        case as_adc: { 
          if (*par!=undefd) {
#           ifdef debug_opti1
            printf("*** %i adc #%i\n",i,*par);
#           endif
            /* replace "adc adr" with "adc #" */
            set_absval(p,*par);
            opt++;
            flag=1; }
          rega=undefd;
          done=1; 
          break; }

        case as_sbc: { 
          if (*par!=undefd) {
#           ifdef debug_opti1
            printf("*** %i sbc #%i\n",i,*par);
#           endif
            /* replace "sbc adr" with "sbc #" */
            set_absval(p,*par);
            opt++;
            flag=1; }
          rega=undefd;
          done=1;
          break; }

        case as_cmp: { 
          if (*par!=undefd) {
#           ifdef debug_opti1
            printf("*** %i cmp #%i\n",i,*par);
#           endif
            /* replace "cmp adr" with "cmp #" */
            set_absval(p,*par);
            opt++;
            flag=1; }
          done=1; 
          break; }

        case as_cpx: { 
          if (*par!=undefd) {
#           ifdef debug_opti1
            printf("*** %i cpx #%i\n",i,*par);
#           endif
            /* replace "cpx adr" with "cpx #" */
            set_absval(p,*par);
            opt++;
            flag=1; }
          done=1; 
          break; }

        case as_cpy: { 
          if (*par!=undefd) {
#           ifdef debug_opti1
            printf("*** %i cpy #%i\n",i,*par);
#           endif
            /* replace "cpy adr" with "cpy #" */
            set_absval(p,*par);
            opt++;
            flag=1; }
          done=1; 
          break; }

        case as_ldx: {
          if (*par!=undefd) {
#           ifdef debug_opti1
            printf("*** %i ldx #%i\n",i,*par);
#           endif
            /* replace "ldx adr" with "ldx #" */
            set_absval(p,*par);
            opt++;
            flag=1; }
          regx=*par;
          done=1; 
          break; }

        case as_ldy: {
          if (*par!=undefd) {
#           ifdef debug_opti1
            printf("*** %i ldy #%i\n",i,*par);
#           endif
            /* replace "ldy adr" with "ldy #" */
            set_absval(p,*par);
            opt++;
            flag=1; }
          regy=*par;
          done=1; 
          break; }
	  }
	}
    switch (p->tok) {
      case as_inx: { if (regx!=undefd) regx=0xff&(regx+1); done=1; break; }
      case as_iny: { if (regy!=undefd) regy=0xff&(regy+1); done=1; break; }
      case as_dex: { if (regx!=undefd) regx=0xff&(regx-1); done=1; break; }
      case as_dey: { if (regy!=undefd) regy=0xff&(regy-1); done=1; break; } 
	}

  if (i!=j) line_copy(&blkbuf[j],&blkbuf[i]);

  if (done==0) {
    if ( p->mod & reg_a ) rega=undefd;
    if ( p->mod & reg_x ) regx=undefd;
    if ( p->mod & reg_y ) regy=undefd;
    if ( p->depind & p->mod & mem ) mpar_flag[p->mpar]=undefd;
    j++; }
  else { if (done==2) { opt++; flag=1; } else j++; }

  i++; } 
  
  blkbuf_len=j;
  return (flag);
}

/*********************************************************************/

int  changeable(int aa, int bb)
{
  /* check if commands a,b can be exchanged */
  /* (no check of fixed-flags !)            */

  line *a,*b;

# ifdef debug
  printf("check %i,%i :",aa,bb);
# endif

  a=&blkbuf[aa]; b=&blkbuf[bb];

  if (a->feeds & b->dep & valid_map) { dbmsg("no\n"); return 0; }
  if (a->mod & b->feeds & valid_map) { dbmsg("no\n"); return 0; }
  if (a->dep & b->mod & valid_map  ) { dbmsg("no\n"); return 0; }

  if ((a->par!= b->par) || (a->par==no_par)) { dbmsg("yes\n"); return 1; }

  if (a->mod & b->dep) { dbmsg("no\n"); return 0; }
  if (a->mod & b->mod) { dbmsg("no\n"); return 0; }
  if (a->dep & b->mod) { dbmsg("no\n"); return 0; }
  
  dbmsg("yes\n");
  return 1;
}

int no_dep(int a, int b, int map)
{
  while (a<b) {
    if ( (blkbuf[a].dep & map) ) return 0;
    a++; }
  return 1;
}

/*********************************************************************/

void repl1(int i, int j, int parsrc, int newtok)
{
  int x;
  line *lj, *lparsrc;

   if (test_match) return;

  lj=&blkbuf[j];
  lparsrc=&blkbuf[parsrc];

  lj->tok    =newtok;
  lj->dep    =tok[newtok].dep | (lparsrc->depind & valid_map);
  lj->depind =lparsrc->depind;
  lj->mod    =tok[newtok].mod;
  lj->flags  =tok[newtok].flags;
  lj->par    =lparsrc->par;
  lj->mpar   =lparsrc->mpar;
  lj->mparhi =lparsrc->mparhi;

# ifdef debug
  printf("erase line %i, replace line %i with...\n",i,j);
  lineout(&blkbuf[j]);
# endif

  x=i;
  while( x<blkbuf_len ) {
    line_copy(&blkbuf[x],&blkbuf[x+1]);
    x++; }

  blkbuf_len--;
  opt++;
}

void set_tcom(int j, int com)
{
  line *lj;

  if (test_match) return;

  lj=&blkbuf[j];

  lj->tok    =com;
  lj->dep    =tok[com].dep;
  lj->mod    =tok[com].mod;
  lj->depind =0;
  lj->flags  =tok[com].flags;
  lj->par    =no_par;
  opt++;
}

/****************************************************************************/

int add_dep(line *p, int hlp, int map)
{
    hlp=((hlp & ( ~p->mod )) | p->dep) & valid_map;

    if (p->depind & mem) { 

      if (p->depind & imem) {

        /* dep: ptr,ptr+1 */
 
        mpar_flag[p->mpar]|=map;
        mpar_flag[p->mparhi]|=map;

        if (p->dep&mem) hlp|=imem; }

      else if (p->depind & (reg_x|reg_y) ) {
      
        /* dep: ptr */

        mpar_flag[p->mpar]|=map;

        if (p->dep&mem) hlp|=imem; }

      else
  
        /* normal addressed memory (direct) */

        if ( mpar_flag[p->mpar]!=0 && (p->mod & mem)!=0 ) mpar_flag[p->mpar]&=~map;
        if (p->dep & mem) mpar_flag[p->mpar]|=map;
    }

  return hlp;
}

#ifdef debug_opti2

void reglistout(int map)
{
  int i;
  i=0;
  while (i<mpar_num) {
    if (mpar_flag[i]&map) printf("%s ",&mparbuf[mpar_pos[i]]);
    i++; }
}

#endif

int try_sim2(int i, int j)
{
  int j_end,x,y;
  int hlp;
  int flag;
  int A_dep,A_mod,A_feeds,rest_dep;
  int B_dep,B_mod,Brest_dep;

  /* the block boundarys of the first one (A) are known [i+1,...,j-1] */
  /* calculate A.dep, A.mod and A.feeds */

  x=0;
  while (x<mpar_num) mpar_flag[x++]=1; /* all mpar used later */

  rest_dep=blk_mod|imem;

  x=blkbuf_len-1;
  while (x>=j) rest_dep=add_dep(&blkbuf[x--],rest_dep,1);

  A_dep=0;
  while (x>i) A_dep=add_dep(&blkbuf[x--],A_dep,4);

  A_mod=0;
  x=j-1;
  while (x>i) {
    A_mod|=blkbuf[x].mod;
    if( (blkbuf[x].depind & mem)!=0 && (blkbuf[x].mod & mem)!=0 ) {
      if (blkbuf[x].depind&(imem|reg_x|reg_y)) A_mod|=imem;
      else {
        mpar_flag[blkbuf[x].mpar]|=8;
        if (mpar_flag[blkbuf[x].mpar]&1) mpar_flag[blkbuf[x].mpar]|=2; } }
    x--; }
  A_mod&=valid_map|imem;

  A_feeds=rest_dep & A_mod & (valid_map|imem);

#ifdef debug_opti2

  printf("BLOCK A-summaries :");
  printf("\n  A.dep="); mapout(A_dep);
  printf("\n        "); reglistout(4);
  printf("\n  A.mod="); mapout(A_mod);
  printf("\n        "); reglistout(8);
  printf("\n A.feed="); mapout(A_feeds);
  printf("\n        "); reglistout(2);
  printf("\n  r_dep="); mapout(rest_dep);
  printf("\n        "); reglistout(1);
  printf("\n");

#endif

  /* now try to find end of block B */

  /*  1) B_mod must not match A_dep  */

  j_end=j+1;
  while (j_end<blkbuf_len) {
    if (blkbuf[j_end].mod & A_dep) break;
    if( (blkbuf[j_end].depind & mem)!=0 && (blkbuf[j_end].mod & mem)!=0 ) {
      if ((blkbuf[j_end].depind&(imem|reg_x|reg_y))!=0 && (A_dep&imem)!=0) break;
      else if (mpar_flag[blkbuf[j_end].mpar]&4) break; }
    j_end++; }
    
# ifdef debug_opti2
  printf("found j_end_max=%i\n",j_end);
# endif

  while (j_end>j+1) {

    /*  2) calculate Brest_dep, B_mod (B_feeds must not match A_mod) */
 
    x=0;
    while (x<mpar_num) {
      mpar_flag[x]=(mpar_flag[x]&15)|16; /* all mpar used later */
      x++; }

    Brest_dep=blk_mod|imem;

    x=blkbuf_len-1;
    while (x>=j_end) Brest_dep=add_dep(&blkbuf[x--],Brest_dep,16);

    B_mod=0; y=0; /* y used as flag */
    x=j_end-1;
    while (x>=j && y==0) {
      B_mod|=blkbuf[x].mod;
      if( (blkbuf[x].depind & mem)!=0 && (blkbuf[x].mod & mem)!=0 ) {
        if (blkbuf[x].depind&(imem|reg_x|reg_y)) B_mod|=imem;
        else {
          if ( (mpar_flag[blkbuf[x].mpar]&4)!=0 ) 
            { y=1; continue; } /* B_mod matched A_dep */
          if ( (mpar_flag[blkbuf[x].mpar]&(16|8))==(16|8) ) 
            { y=1; continue; } /* B_feeds matched A_mod */ 
        } 
      }
      x--; }

    if (y) { j_end--; continue; }

    B_mod&=valid_map|imem;

    printf("Brest_dep = "); mapout(Brest_dep); printf("\n");
    printf("B_mod     = "); mapout(B_mod); printf("\n");
    
    if (Brest_dep & B_mod & A_mod) { j_end--; continue; }; /* B_feeds matches A_mod so skip */

    /*  1) B_mod must not match A_dep */

    if (B_mod & A_dep) { j_end--; continue; }

    /*  3) A_feeds not in B_dep */

    B_dep=0;
    x=j_end-1;
    while (x>=j) B_dep=add_dep(&blkbuf[x--],B_dep,32);

    if (B_dep & A_feeds & (valid_map|imem)) { j_end--; continue; }

    x=0;
    while (x<mpar_num && (mpar_flag[x]&(2|32))!=(2|32) ) x++;
    if (x!=mpar_num) { j_end--; continue; }

    break;

  }

# ifdef debug_opti2
  printf("j_end is %i\n\n",j_end);
# endif

  if (j_end>=blkbuf_len) {
    dbmsg("### no need to move\n");
    return 0; }

  if (j_end<=j+1) {
    dbmsg("### to small to move\n");
    return 0; }

  x=j_end-j-1;
  while (x>=0) {
    iline_copy(blkbuf_len+x, j+x);
    x--; }
  x=j-i-2;
  y=i+(j_end-j)+1;
  while (x>=0) {
    iline_copy(y+x, i+1+x);
    x--; }
  x=j_end-j-1;
  while (x>=0) {
    iline_copy(i+1+x, blkbuf_len+x);
    x--; }
  return 1;

}

int opti2()
{
  int i,j;
  int flag;
  line *tmp,*il,*jl;

  /* Search for "sta tmp,...,lda tmp" and try to simplify */

  tmp=&blkbuf[blkbuf_len];
  test_match=0;

  /* first move all "cl/se ldy #,iny,dey" up as much as possible */

  i=0;
  while (i<blkbuf_len) {
    if (blkbuf[i].flags & isinit) {
      if ( blkbuf[i].tok==as_ldy && (blkbuf[i].depind & mem)!=0 ) { i++; continue; }
      j=i-1;
      while (j>=0 && changeable(j,j+1)) {
        il=&blkbuf[j+1];
        jl=&blkbuf[j--];
        line_copy(tmp,il);
        line_copy(il,jl);
        line_copy(jl,tmp); } }
  i++; }

  make_feedlist();

  /* search for "sta tmp,lda tmp" or "tax,txa" */

  i=0;
  while (i<blkbuf_len) {
    if (blkbuf[i].tok==as_sta && (blkbuf[i].depind&(reg_x|reg_y))==0) {
      j=i+1;
      while (j<blkbuf_len) {
        if (blkbuf[j].par==blkbuf[i].par && blkbuf[j].tok==as_lda) {
#         ifdef debug
          printf("### found sta/lda at %i/%i\n",i,j);
#         endif
          if (try_sim2(i,j)) return 1; }
        else if (blkbuf[j].par==blkbuf[i].par) break;
	  j++; }
	}

    if (blkbuf[i].tok==as_tax) {
      j=i+1;
      while (j<blkbuf_len) {
        if (blkbuf[j].tok==as_txa) {
#         ifdef debug
          printf("### found tax/txa at %i/%i\n",i,j);
#         endif
          if (try_sim2(i,j)) return 1; }
        else if (blkbuf[j].dep&reg_x) break;
      j++; }
	}

  i++; }

  /* so, can't move blocks but may be we can use registers
     istead of tmpxx ? */

  /* first move all "ldy #" down as much as possible */

  i=0;
  while (i<blkbuf_len) {
    if (blkbuf[i].tok==as_ldy && (blkbuf[i].depind&mem)==0) {
      j=i;
      while (j<blkbuf_len-1 && changeable(j,j+1)) {
        il=&blkbuf[j+1];
        jl=&blkbuf[j++];
        line_copy(tmp,il);
        line_copy(il,jl);
        line_copy(jl,tmp); } }
  i++; }

  make_feedlist();

  i=0;
  while (i<blkbuf_len) {
    if (blkbuf[i].tok==as_sta && (blkbuf[i].depind&(reg_x|reg_y))==0) {
      j=i+1; flag=blkbuf[i].passes;
      while (j<blkbuf_len) {
        flag|=blkbuf[j].mod|blkbuf[j].dep;
        if (blkbuf[j].par==blkbuf[i].par && blkbuf[j].tok==as_lda && (blkbuf[j].passes & mem)==0 ) {
#         ifdef debug
          printf("### again sta/lda at %i/%i\n",i,j);
#         endif
          /* if y or x unused inbetween, then replace */
          if ( (flag & reg_y)==0 ) {
            dbmsg("*** replace sta,lda -> tay,tya\n");
            set_tcom(i,as_tay); set_tcom(j,as_tya);
            return 1; }
          if ( (flag & reg_x)==0 ) {
            dbmsg("*** replace sta,lda -> tax,txa\n");
            set_tcom(i,as_tax); set_tcom(j,as_txa);
            return 1; } }
        else if (blkbuf[j].par==blkbuf[i].par) break;
	  j++; }
	}
  i++; }

  return 0;
}

/****************************************************************************/

int com_match2_default(int j)
{
  if ( (com_match_lptr->flags & dupl)==0    && \
       com_match_lptr->tok==blkbuf[j].tok   && \
       com_match_lptr->par==blkbuf[j].par        ) {
    op2msg("duplicated command\n");
    repl1(com_match_lnum,j,com_match_lnum,com_match_lptr->tok); 
    return 1; }
  
  return 0;
}

int com_match2_tax(int j)
{
  line *b;
  b=&blkbuf[j];

  if (b->tok==as_txa) { 
    op2msg("tax,txa -> tax\n"); 
    repl1(com_match_lnum,j,com_match_lnum,as_tax); 
    return 1; }

  if (b->tok==as_stx && (b->passes & reg_x)==0) {
    if (!no_dep(com_match_lnum,j,reg_x)) return 0;
    op2msg("tax,stx -> sta\n"); 
    repl1(com_match_lnum,j,j,as_sta); 
    return 1; }

  return com_match2_default(j);
}

int com_match2_txa(int j)
{
  line *b;
  b=&blkbuf[j];

  if (b->tok==as_tax) { 
    op2msg("txa,tax -> txa\n"); 
    repl1(com_match_lnum,j,com_match_lnum,as_txa); 
    return 1; }

  if ( b->tok==as_sta && (b->dep&(reg_x|reg_y))==0 && (b->passes & reg_a)==0 ) {
    if (!no_dep(com_match_lnum,j,reg_a)) return 0;
    op2msg("txa,sta -> stx\n"); 
    repl1(com_match_lnum,j,j,as_stx); 
    return 1; }

  return com_match2_default(j);
}

int com_match2_tay(int j)
{
  line *b;
  b=&blkbuf[j];

  if (b->tok==as_tya) { 
    op2msg("tay,tya -> tay\n"); 
    repl1(com_match_lnum,j,com_match_lnum,as_tay); 
    return 1; }

  if (b->tok==as_sty && (b->passes & reg_y)==0) {
    if (!no_dep(com_match_lnum,j,reg_y)) return 0;
    op2msg("tay,sty -> sta\n"); 
    repl1(com_match_lnum,j,j,as_sta); 
    return 1; }

  return com_match2_default(j);
}

int com_match2_tya(int j)
{
  line *b;
  b=&blkbuf[j];

  if (b->tok==as_tay) { 
    op2msg("tya,tay -> tya\n"); 
    repl1(com_match_lnum,j,com_match_lnum,as_tya); 
    return 1; }

  if ( b->tok==as_sta && (b->dep&(reg_x|reg_y))==0 && (b->passes & reg_a)==0 ) {
    if (!no_dep(com_match_lnum,j,reg_a)) return 0;
    op2msg("tya,sta -> sty\n"); 
    repl1(com_match_lnum,j,j,as_sty); 
    return 1; }

  return com_match2_default(j);
}

int com_match2_txs(int j)
{
  if (blkbuf[j].tok==as_tsx) {
    op2msg("txs,tsx -> txs\n"); 
    repl1(com_match_lnum,j,com_match_lnum,as_txs); 
    return 1; }
  
  return com_match2_default(j);
}

int com_match2_tsx(int j)
{
  if (blkbuf[j].tok==as_txs) {
    op2msg("tsx,txs -> tsx\n"); 
    repl1(com_match_lnum,j,com_match_lnum,as_tsx); 
    return 1; }

  return com_match2_default(j);
}

int com_match2_lda(int j)
{
  line *b;
  b=&blkbuf[j];

  if ( (b->passes & reg_a)==0 && (com_match_lptr->dep&(reg_x|reg_y))==0 ) {
    if (b->tok==as_tax) { 
      if (!no_dep(com_match_lnum,j,reg_a)) return 0;
      op2msg("lda,tax -> ldx\n"); 
      repl1(com_match_lnum,j,com_match_lnum,as_ldx); 
      return 1; }
    if (b->tok==as_tay) {
      if (!no_dep(com_match_lnum,j,reg_a)) return 0;
      op2msg("lda,tay -> ldy\n"); 
      repl1(com_match_lnum,j,com_match_lnum,as_ldy); 
      return 1; }
    }

  if ( b->tok==as_sta && com_match_lptr->par==blkbuf[j].par ) { 
    op2msg("lda,sta -> lda\n"); 
    repl1(com_match_lnum,j,com_match_lnum,as_lda); 
    return 1; }

  return com_match2_default(j);
}

int com_match2_ldx(int j)
{
  line *b;
  b=&blkbuf[j];

  if (b->tok==as_txa && (b->passes & reg_x)==0) {
    if (!no_dep(com_match_lnum,j,reg_x)) return 0;
    op2msg("ldx,txa -> lda\n"); 
    repl1(com_match_lnum,j,com_match_lnum,as_lda); 
    return 1; }

  if ( b->tok==as_stx && com_match_lptr->par==b->par ) {
    op2msg("ldx,stx -> ldx\n"); 
    repl1(com_match_lnum,j,com_match_lnum,as_ldx); 
    return 1; }

  return com_match2_default(j);
}

int com_match2_ldy(int j)
{
  line *b;
  b=&blkbuf[j];

  if (b->tok==as_tya && (b->passes & reg_y)==0) { 
    if (!no_dep(com_match_lnum,j,reg_y)) return 0;
    op2msg("ldy,tya -> lda\n"); 
    repl1(com_match_lnum,j,com_match_lnum,as_lda); 
    return 1; }

  if ( b->tok==as_sty && com_match_lptr->par==b->par ) {
    op2msg("ldy,sty -> ldy\n"); 
    repl1(com_match_lnum,j,com_match_lnum,as_ldy); 
    return 1; }

  return com_match2_default(j);
}

int com_match2_sta(int j)
{
  line *b;
  b=&blkbuf[j];

  if (com_match_lptr->par==b->par) {
    if (b->tok==as_lda) { 
      op2msg("sta,lda -> sta\n"); 
      repl1(com_match_lnum,j,com_match_lnum,as_sta); 
      return 1; }
    if (b->tok==as_ldx) { 
      op2msg("sta,ldx -> sta,tax\n"); 
      set_tcom(j,as_tax); 
      return 1; }
    if (b->tok==as_ldy) { 
      op2msg("sta,ldy -> sta,tay\n"); 
      set_tcom(j,as_tay); 
      return 1; }
  }

  return com_match2_default(j);
}

int com_match2_stx(int j)
{
  line *b;
  b=&blkbuf[j];

  if (com_match_lptr->par==b->par) {
    if (b->tok==as_ldx) { 
      op2msg("stx,ldx -> stx\n"); 
      repl1(com_match_lnum,j,com_match_lnum,as_stx); 
      return 1; }
    if (b->tok==as_lda) { 
      op2msg("stx,lda -> stx,txa\n"); 
      set_tcom(j,as_txa); 
      return 1; }
  }

  return com_match2_default(j);
}

int com_match2_sty(int j)
{
  line *b;
  b=&blkbuf[j];

  if (com_match_lptr->par==b->par) {
    if (b->tok==as_ldy) { 
      op2msg("sty,ldy -> sty\n"); 
      repl1(com_match_lnum,j,com_match_lnum,as_sty); 
      return 1; }
    if (b->tok==as_lda) { 
      op2msg("sty,lda -> sty,tya\n"); 
      set_tcom(j,as_tya); 
      return 1; }
  }

  return com_match2_default(j);
}

/****************************************************************************/

int (*com_match1(int i))()
{
  /* find match for first command (of two) and return pointer to com_match2-function */

  dbmsg("com_match1\n");

  com_match_lnum=i;
  com_match_lptr=&blkbuf[i];

  switch (com_match_lptr->tok) {
    case as_tax: return com_match2_tax;
    case as_txa: return com_match2_txa;
    case as_tay: return com_match2_tay;
    case as_tya: return com_match2_tya;
    case as_txs: return com_match2_txs;
    case as_tsx: return com_match2_tsx;
    case as_lda: return com_match2_lda;
    case as_ldx: return com_match2_ldx;
    case as_ldy: return com_match2_ldy;
    case as_sta: return com_match2_sta;
    case as_stx: return com_match2_stx;
    case as_sty: return com_match2_sty;
    default:     return com_match2_default;
  }
  return NULL;
}

int opti3()
{
  static int i,j,x,y;
  static int (*com_match2)();
  static line *il,*jl,*tmp;

  tmp=&blkbuf[blkbuf_len];

  i=0;
  while (i<blkbuf_len-1) {
    test_match=0;
    com_match2=com_match1(i);
    if (com_match2==NULL || (blkbuf[i].flags & fixed)!=0 ) { i++; continue; }
    j=i+1;
    while (j<blkbuf_len) {
      if (blkbuf[j].flags & fixed) break; /* don't move through fixed items */
#     ifdef debug
      printf("o+: %i,%i ?\n",i,j);
#     endif
      if (com_match2(j)) return 1;
      if (!changeable(i,j)) break;
      j++; }
    x=j+1;
    test_match=1;
    while (x<blkbuf_len) {
      if (blkbuf[j].flags & fixed) break; /* don't move through fixed items */
#     ifdef debug
      printf("o-: %i,%i\n",i,x);
#     endif
      if (!com_match2(x)) { x++; continue; }
      y=x-1;
      while (y>j && changeable(y,x)) y--;
      if (y==j && changeable(y,x)) {
        /* move x upwards to position j */
        y=x-1;
        while (y>=j) {
          il=&blkbuf[y];
          jl=&blkbuf[y+1];
          line_copy(tmp,il);
          line_copy(il,jl);
          line_copy(jl,tmp);
          y--; }
        test_match=0;
        com_match2(j);
        return 1; }
      x++; }
    i++; }

  return 0;
}
     
/*********************************************************************/

void add_line(line *p)
{
  if (blkbuf_len+1==blkbuf_max) {
    printf("error: block-buffer overrun\n");
    exit(1); }
  if (blkbuf_len==0) was_line=inp_line;
  line_copy(&blkbuf[blkbuf_len],p);
  blkbuf_len++;

# ifdef debug_parse
  printf("line %i added tok=%i\n",blkbuf_len-1,blkbuf[blkbuf_len-1]);
# endif
}

optimize_block()
{
  int i;

  if (blkbuf_len<1) return;
  
  dbmsg("<BLOCK>\n");

  opt=0;

 while (1) {
  make_feedlist();

# ifdef debug
  i=0;
  while (i<blkbuf_len) {
    printf("%3i:",i);
    lineout(&blkbuf[i]);
    i++; }
# endif

  dbmsg("simple...\n");
  if (simple_erase()) continue;

  dbmsg("opti1...\n");
  if (opti1()) continue;

  dbmsg("opti2...\n");
  if (opti2()) continue;

  dbmsg("opti3...\n");
  if (opti3()) continue;

  break;
  }

# ifdef debug
  printf("<result>\n");
  i=0;
  while (i<blkbuf_len) {
    printf("%3i ",i);
    lineout(&blkbuf[i]);
    i++; }
# endif

  printf("\n");
  if (opt!=0) printf("  ; REMOVED %i was line %i\n",opt,was_line);
  bufout();
  printf("\n");

  blkbuf_len=0;  /* erase block-buffer */
}

/*********************************************************************/

main(int argc, char **argv)
{
  char linebuf[line_len];
  line tmp;
  int  ret;
  FILE *fin;
  int  i;
  int  wall_flag;

  if (argc<2) how_to();
  fin=fopen(argv[1],"r");
  if (fin==NULL) { printf("can't open file\n"); exit(1); }

  par_used=0;
  par_num=0;
  blkbuf_len=0;
  wall_flag=0;
  inp_line=0;

  while(readline(linebuf,fin)!=EOF) {

    i=nextchar(linebuf,0);
    if (linebuf[i]=='u' && linebuf[i+1]=='s' && linebuf[i+2]=='e') {

      /* read blk_mod from input-line */
      i=nextchar(linebuf,i+3);
      blk_mod=0;
      while (linebuf[i]!='\0') {
        switch (linebuf[i]) {
          case 'a':  { wall_flag=reg_a; break; }
          case 'x':  { wall_flag=reg_x; break; }
          case 'y':  { wall_flag=reg_y; break; }
          case 'n':  { wall_flag=flag_n; break; }
          case 'z':  { wall_flag=flag_z; break; }
          case 'v':  { wall_flag=flag_v; break; }
          case 'c':  { wall_flag=flag_c; break; }
          case 'd':  { wall_flag=flag_d; break; }
          case 'i':  { wall_flag=flag_i; break; }
          default :  { 
            printf("  error: unknown flag/register \"%c\"\n",linebuf[i]); exit(1); }          
		  }
        blk_mod|=wall_flag; 
        i=nextchar(linebuf,i+1); }

      wall_flag=1;
      continue; }

    ret=parse_line(linebuf, &tmp);

    if (ret!=0) {
      if (!wall_flag) blk_mod=valid_map;
      optimize_block();
      wall_flag=0;
      if ( tmp.tok==no_tok  || ret>1 || (tmp.flags & isjmp)!=0 ) { clear_buf(); puts(linebuf); }
      else { /* only print label */
        i=nextchar(linebuf,0);
        while ( linebuf[i]!='\0' && linebuf[i]!=' ' && linebuf[i]!='\t' ) 
          putc(linebuf[i++],stdout); 
        printf("\n");
        if (tmp.tok!=null_tok) add_line(&tmp); }
      continue; }

    if (tmp.tok==null_tok) {
#     ifdef debug_parse
      puts(linebuf);
#     endif
      continue; }

    if ( tmp.tok==no_tok || (tmp.flags & isjmp)!=0 ) {
      if (!wall_flag) blk_mod=valid_map;
      optimize_block();
      puts(linebuf);
      clear_buf(); }
    else { if (tmp.tok==as_jsr) printf("argh!"); 
           add_line(&tmp); }
  wall_flag=0;
  }

  fclose(fin);
}
