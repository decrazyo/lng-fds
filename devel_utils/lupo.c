/* LUnix-preprocessor (lupo) Version 0.21

   Written by Daniel Dallmann (aka Poldi) in Sep 1996.
   This piece of software is freeware ! So DO NOT sell it !!
   You may copy and redistribute this file for free, but only with this header
   unchanged in it. (Or you risc eternity in hell)

   If you've noticed a bug or created an additional feature, let me know.
   My (internet) email-address is dallmann@heilbronn.netsurf.de

 Sep 30 2001 *poldi* fixed bug in process_line()

 Apr 11 2001 *poldi* DEFINES_MAX now 1000 (was 500)

 Sep 7 2000  *poldi* INCLUDE_DEPTH_MAX now 8 (was 5) + fixed segfault on hitting limit

 Dec 23 1999 *poldi* fixed bug in processing of special functions
                     that occured with option "-r" enabled

 Jun  9 1999 *poldi* code cleaning

 Jun 8       *Stefan Haubenthal* AMIGA related patches

 Feb 20 1998 *poldi* fixed: small bug with special functions
 
 Oct  9 *poldi* changed: '.' now is a separator
 
 Jun 29 *poldi* fixed: nested macros
                fixed: expand marcos in remarks ??

 Jun 26 *Stefan Haubenthal*
                added: predefined: _LUPO_
                                   _DATE_ "(Month #day #year)"

 Jun 21 *poldi* added: searchpath for includes now read from environment
                       LUPO_INCLUDEPATH

 May 20 *poldi* added: -q option (quiet mode)

 May 18 *paul g-s* 
                feature: Added -l option to add a .line directive before 
		         each line of source.
			 This slows it down a litte, but means luna can give
			 the line an error was found in the original .c
		fix:     Changed error messages to be meaningful for emacs
		fix:     Added system include facility (#include <foo.h>)
		         Directories searched for includes are (in order):
			 /usr/include/c64, /usr/include/lunix, /usr/include
			 /usr/local/include/c64,
			 /usr/local/include/lunix,
			 and /usr/local/include
		bugfix:  You can now have quoted parameters in macros with
		         seperators

 May  6 *poldi* bugfix: nested macros. 

 Apr  3 *poldi* bugfix: Tabs in macro-definitions.

 Mar 21 1997 *poldi* added:  specialfunction directives
                        %%<commandlist>%%
                        with commandlist = {command{,command}+}
                        and command one of
                          next - generate next unique label
                          pcur - print current label (last generated)
                          ptop - print first label on special-stack
                          plast- print 2nd label on special-stack
                          plast[ 2..9] - print 3rd, 4, 5... label from stack
                          push - push current label on stack
                          pop  - remove top stack element
                          swap - swap upper two stack elements
                          swap[ 2..9]. swap deeper stack elements

 Dec 16 *poldi* bugfix: ";" now isn't a remark, when in a string.

 Nov  3 *poldi* bugfix: tabs now really are white spaces
                        "." may be part of macro-names.
                feature: lupo now removes remarks (prefixed by ";")
                         this can be switched off (-r option)
*/

#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>

/* #define debug */

/* Function prototypes */
void Howto(void);
int  get_expr(char*, int*);
int  pushSourceFile(char*);
int  popSourceFile(void);
char *getSourceFile(void);
FILE *fopenSystemInclude(char*);
void error(char*);
int nextchar(char*, int);
int is_sep(char);
char *str_sav(char*);
int readline(char*);
int match(char* ,int, char*);
int search_def(char*);
int get_term(char*, int*);
int get_term(char*, int*);
int get_sum(char*, int*);
int special_function(char*);
void process_line(char*);
void process_line_spec(char*);
int read_macro_def(char*, int*);
void add_define(char*, char*);
void macroout(char *);


#define USE_GETENV     /* use LUPO_INCLUDEPATH to find includefiles */

#ifdef _AMIGA
 const char *VERsion="$VER: lupo 0.21 "__AMIGADATE__" $";
# define PATH_SEPARATOR ','      /* character used as path separator */
#else
# define PATH_SEPARATOR ':'      /* character used as path separator */
#endif

#define DIRECTORY_SEPARATOR '/' /* character used as dir. separator */

  /* export LUPO_INCLUDEPATH=/usr/include/c64:/usr/include/lunix
                                             ^            ^ dir. separator
                                       path separator
  */

#define TIMEFORMAT "\"(%b %d %Y) \""  /* format string for strftime() */
                                      /* used to predefine _DATE_     */
#define INCLUDE_DEPTH_MAX 8
#define IF_DEPTH_MAX 10
#define LINE_LENGTH_MAX 500
#define DEFINES_MAX 1000
#define MACRO_LENGTH_MAX 1000
#define PARAMETERS_MAX 10          /* not over 30 ! */
#define SPEC_LAB_STACK_SIZE 20     /* max depth of stack */

#define NO_MATCH 0x6fff

static FILE *infile;
static int  line;
static int  lpos[INCLUDE_DEPTH_MAX];
static char *infilename[INCLUDE_DEPTH_MAX];
static FILE *infilestream[INCLUDE_DEPTH_MAX];
static int  infiles;
static int  errors;

static char *defs[DEFINES_MAX];
static int  parcount[DEFINES_MAX];
static char *repl[DEFINES_MAX];
static char *mpar[PARAMETERS_MAX];
static int  defcount;
static int  remove_remarks;
static int  add_dotLines;

static int  spec_label_count;
static int  spec_lab_stack[SPEC_LAB_STACK_SIZE];
static int  spec_lab_stack_ptr;

/* This is where getSourceFile() builds the source pedigree string */
char sourcePedigree[8192];
/* This is where the previous source pedigree is kept 
   (for ensuring terseness of error output) */
static char oldSourcePedigree[8192];

void error(char *message)
{
  static int i;

  if ((infiles>0)&&(strcmp(oldSourcePedigree,getSourceFile())))
    {
      i=infiles;
      printf("In file \"%s\",",infilename[i]);
      i--;
      while(i>=0) {
	printf("Included from %s:%i\n",infilename[i],lpos[i]);
	i--; }
      /* Update source pedigree */
      strcpy(oldSourcePedigree,getSourceFile());
  }
  printf("%s:%i: %s\n",infilename[infiles],line,message);

  errors++;
}

void Howto() 
{
  printf("lupo [-dloqrs] file\n");
  printf("  little universal preprocessor version 0.21\n");
  printf("  -dname[=macro] - predefine macro\n");
  printf("  -l             - Insert .line directives for error tracking\n");
  printf("  -o file        - define outputfile (default lupo.out)\n");
  printf("  -q             - quiet mode\n");
  printf("  -r             - don't remove remarks\n");
  printf("  -s             - don't remove leading spaces\n");
#ifdef USE_GETENV
  printf(" environment\n");
  printf("  LUPO_INCLUDEPATH used to search for includefiles.\n");
#endif
  exit(1);
}

int nextchar(char *string, int pos)
{
  /* printf("nexchar:\"%s\"\n",&string[pos]); */

  while (string[pos]==' ' || string[pos]=='\t') pos++;
  return pos;
}

int is_sep(char a)
{
  if ( (a>='a' && a<='z') ||
       (a>='A' && a<='Z') ||
       (a>='0' && a<='9') ||
       a=='_' || a=='@' ||
       a=='ö' || a=='Ö' ||
       a=='ü' || a=='Ü' ||
       a=='ä' || a=='Ä' ||
       a=='ß' ) return 0;

  return 1;
}

#ifdef debug

void macroout(char *mac)
{
  int i;

  printf("\"");
  i=0;
  while (mac[i]!='\0') {
    if (mac[i]<32) printf("\\%i",mac[i]);
    else printf("%c",mac[i]);
    i++; }
  printf("\"\n");
}

#endif

char *str_sav(char *string)
{
  char *hlp;

# ifdef debug  
  printf("str_sav:"); macroout(string);
# endif

  hlp=(char *)malloc(strlen(string)+1);
  if (hlp==NULL) { error("out of memory"); exit(1); }
  strcpy(hlp,string);
  return hlp;
}

int readline(char *buffer)
{
  int i=0, quoted=0;
  static int tmp;
  line++;

  if (infiles<0) return EOF;

  while (1) {
    if (i==LINE_LENGTH_MAX-1) { 
      error("line too long");
      buffer[i]='\0';
      return 0; }
    tmp=getc(infile);
    if (tmp==EOF) {
      if (quoted) error("stray \\");
      if (i==0) {
        fclose(infile);
	popSourceFile(); /* remove filename from the stack for .line's */
        if (infiles==0) { infiles=-1; return EOF; }
        free(infilename[infiles]);
        infiles--;
        infile=infilestream[infiles];
        line=lpos[infiles]; }
      buffer[i]='\0';
      return 0; }
    if (tmp=='\\' && !quoted) { quoted=1; continue; }
    if (tmp=='\n') {
      if (quoted) { line++; quoted=0; continue; }
      buffer[i]='\0';
      return 0; }
    if (tmp<32 && tmp!='\t') continue;
    if (quoted) { buffer[i++]='\\'; quoted=0; }
    buffer[i++]=tmp; }
}

int match(char *string,int pos,char *pattern)
{
  int i=0;

  while (pattern[i]!='\0') {
    if (pattern[i]!=string[pos+i]) return NO_MATCH;
    i++; }

  if (!is_sep(string[pos+i])) return NO_MATCH;
  return pos+i;
}

int search_def(char *name)
{
  int i;
 
  i=0;
  while (i<defcount) {
    if (!strcmp(defs[i],name)) return i;
    i++; }

  return NO_MATCH;
}

int get_term(char *line_in, int *pos)
{
  int tmp;
  int hlp,hlp2;

  *pos=nextchar(line_in,*pos);

  if (line_in[*pos]=='!') {
    *pos+=1;
    return get_term(line_in,pos) ? 0:1 ; }

  if (line_in[*pos]=='(') {
    *pos+=1;
    tmp=get_expr(line_in,pos);
    *pos=nextchar(line_in,*pos);
    if (line_in[*pos]!=')') error("syntax");
    *pos+=1;
    return tmp; }
  
  /* or val */

  hlp=*pos;
  while (!is_sep(line_in[hlp])) hlp++;
  hlp2=line_in[hlp];
  line_in[hlp]='\0';
  if (search_def(&line_in[*pos])!=NO_MATCH) tmp=1; else tmp=0;
  line_in[hlp]=hlp2;
  *pos=hlp;
  return tmp; 
}

int get_sum(char *line_in, int *pos)
{
  int tmp;

  tmp=1;
  while(1) {
    tmp=tmp & get_term(line_in,pos);
    *pos=nextchar(line_in,*pos);
    if (line_in[*pos]!='&') return tmp;
    *pos+=1; }
} 

int get_expr(char *line_in, int *pos)
{
  int tmp;

  tmp=0;
  while(1) {
    tmp=tmp | get_sum(line_in,pos);
    if (line_in[*pos]!='|') return tmp;
    *pos+=1; }
} 

/* Special funktions look like:  %%<commlist>%%
   with commlist: {comm}{,comm}+
   with comm:    next,pcur,ptop,plast[n],push,pop,swap[n] */

int special_function(char *l)
{
  char replbuf[8];
  int  i,j,f,n;

  n=f=0;
  i=2;
  while (l[i]!='\0') {

    if (l[i]=='%' && l[i+1]=='%') {
      i++; 
      break; } /* end of commlist */

    while (1) {
      if ((n=match(l,i,"next"))!=NO_MATCH) {
        /* next - gernerate next label */
        spec_label_count++;
        break; }

      if ((n=match(l,i,"pcur"))!=NO_MATCH) {
        /* pcur - prints current label */
        sprintf(replbuf,"__%i",spec_label_count);
        if (f) error("more than one print command in specialfunction");
        f=-1;
        break; }

      if ((n=match(l,i,"ptop"))!=NO_MATCH) {
        /* ptop - prints top stack element */
        if (spec_lab_stack_ptr==0)
          error("specialstack underflow");
        else
          sprintf(replbuf,"__%i",spec_lab_stack[spec_lab_stack_ptr-1]);
        if (f) error("more than one print command in specialfunction");
        f=-1;
        break; }

      if ((n=match(l,i,"plast"))!=NO_MATCH) {
        /* plast - prints last [n] stack element */

        if (l[n]==' ' && l[n+1]>'0' && l[n+1]<='9') {
          j=l[n+1]-'0';
          n+=2; } else j=1;

        if (spec_lab_stack_ptr<=j) {
          error("specialstack underflow");
          strcpy(replbuf,"__null"); }
        else
          sprintf(replbuf,"__%i",spec_lab_stack[spec_lab_stack_ptr-j-1]);
        if (f) error("more than one print command in specialfunction");
        f=-1;
        break; }

      if ((n=match(l,i,"push"))!=NO_MATCH) {
        /* push - pushes current label on specialstack */
        if (spec_lab_stack_ptr>=SPEC_LAB_STACK_SIZE) 
          error("specialstack overflow");
        else
          spec_lab_stack[spec_lab_stack_ptr++]=spec_label_count;
        break; }

      if ((n=match(l,i,"pop"))!=NO_MATCH) {
        /* pop - removes top element from stack */
        if (spec_lab_stack_ptr<1) 
          error("specialstack undeflow");
        else
          spec_lab_stack_ptr--;
        break; }

      if ((n=match(l,i,"swap"))!=NO_MATCH) {
        /* swap [n] - swaps two stack elements (n <-> n-1) */

        if (l[n]==' ' && l[n+1]>'0' && l[n+1]<='9') {
          j=l[n+1]-'0';
          n+=2; } else j=1;

        if (spec_lab_stack_ptr<=j) {
          error("specialstack underflow");
          strcpy(replbuf,"__null"); }
        else {
          int tmp;
          tmp=spec_lab_stack[spec_lab_stack_ptr-j];
          spec_lab_stack[spec_lab_stack_ptr-j]= \
                                       spec_lab_stack[spec_lab_stack_ptr-j-1];
          spec_lab_stack[spec_lab_stack_ptr-j-1]=tmp; }
        break; }

      error("unknown specialfunction");
      
      n=i;
      while (l[n]!='\0' && l[n]!=',' && l[n]!='%') n++;
      break; }

    if (l[n]==',') i=n+1; 
    else {
      i=n;
      if (l[n]!='\0' && l[n]!='%') error("\",\" expected"); }
    }

  /* remove whole specialfunction */

  if (l[i]=='\0') {
    error("unterminated specialfunction");
    l=""; }

  else {
    n=0; i++;
    while ((l[n]=l[i+n])!='\0') n++; }

  /* insert label if neccessary */

  if (f) {
    n=strlen(replbuf);
    i=strlen(l);
    while (i>=0) {
      l[i+n]=l[i];
      i--; }
    n--;
    while (n>=0) {
      l[n]=replbuf[n];
      n--; }
  }

return f;
}

void process_line(char *l)
{
  int  i,need,a,b;
  int  x,y;
  char *tmp;
  char *tmp2;
  char *tmp3;
  int  str_quote,quote;
  static char *loc_mpar[PARAMETERS_MAX];

# ifdef debug
  printf("processing:\"%s\"\n",l);
# endif

  str_quote=quote=0;
  i=0; x=0;
  while (l[i]!='\0') {
    if (x==0) {
      if (!quote && !str_quote) {
        if (!is_sep(l[i])) {
          x=0; y=NO_MATCH;
          while (x<defcount) {
            if ((y=match(l,i,defs[x]))!=NO_MATCH) break;
            x++; }
          if ((y!=NO_MATCH) && (parcount[x]==0 || l[y]=='(') ) {

#           ifdef debug
            printf("match found !\n");
#           endif

            need=strlen(repl[x]);
            if (parcount[x]>0) {
              int quoted=0;
              tmp3=str_sav(l);
              tmp3[y]=',';
              a=0;
              while (a<parcount[x]) {
                if (tmp3[y]==')') { error("missing parameter"); return; }
                if (tmp3[y]!=',') { error("syntax"); return; }
                tmp3[y]='\0';
                b=y=nextchar(l,y+1);
                loc_mpar[a]=&tmp3[b];
                while (tmp3[y]!='\0' && ((tmp3[y]!=',' && tmp3[y]!=')')||
                        quoted)) {
                  if (tmp3[y]=='\"')  quoted^=1; /*"*/
                  y++; }
                if (quoted) error("unterminated string");
                if (tmp3[b]=='\"' && tmp3[y-1]=='\"') { /*"*/
                  /* Strip surrounding quotes */
                  loc_mpar[a]=&tmp3[b+1];
                  tmp3[y-1]='\0'; }
                a++;
                }

              if (tmp3[y]==',')
                { error("too many parameters"); return; }
              if (tmp3[y]!=')')
                { error("syntax"); return; }
              tmp3[y]='\0';
              y++;
              a=0;
              tmp=repl[x];
              while (tmp[a]!='\0') {
                if (tmp[a]<32 && tmp[a]>1) {
                  need+=strlen(loc_mpar[tmp[a]-2])-1; }
                a++; }

#             ifdef debug         
              printf("macroparameters: ");
              a=0;
              while (a<parcount[x]) {
                printf("\"%s\" ",loc_mpar[a]);
                a++; }
              printf("\n");
#             endif

            } 
            else tmp3=NULL;
          
            if (need<y-i) {
              a=i+need; b=y;
              while ( (l[a++]=l[b++])!='\0' );
              l[a]='\0'; }

            if (need>y-i) {
              b=strlen(l); a=b+(need-y+i);
              while (b>=y) l[a--]=l[b--];  }
          
            a=0;
            tmp=repl[x];
            while (tmp[a]!='\0') {
              if (tmp[a]<32 && tmp[a]>1) {
                b=0;
                tmp2=loc_mpar[tmp[a++]-2];
                while (tmp2[b]!='\0') l[i++]=tmp2[b++]; }
              else l[i++]=tmp[a++]; }
	    if (repl[x]!='\0') i--; /* step one back, i++ follows! */

#           ifdef debug
            printf("replaced, now:\"%s\"\n",l);
#           endif

            if (tmp3!=NULL) free(tmp3);
            x=0; }
          else x=1;  } } }
    else {
      if (is_sep(l[i])) x=0;
      }

    if (!quote && !str_quote && l[i]==';') {
      if (remove_remarks) {
        l[i]='\0';
#       ifdef debug
        printf("deleted remark\n");
#       endif
	    }
      return; }

    if (l[i]=='\"' && !quote) { /*"*/
      if (str_quote) str_quote=0; else str_quote=1; }
    if (l[i]=='\\') quote=1; else quote=0;

    i++; }
}

void process_line_spec(char *l)
{
  int  i;
  int  str_quote,quote;

# ifdef debug
  printf("processing_spec:\"%s\"\n",l);
# endif

  str_quote=quote=0;
  i=0;
  while (l[i]!='\0') {
    if (!quote && !str_quote) {
      if (l[i]=='%' && l[i+1]=='%')
        special_function(&l[i]);
      if (l[i]=='\0') break;
      if (l[i]==';') {
	while (l[i]>=32) i++;
	continue; }
    }
    
    if (l[i]=='\"' && !quote) { /*"*/
      if (str_quote) str_quote=0; else str_quote=1; }
    if (l[i]=='\\') quote=1; else quote=0;
    
    i++; } 
}

int read_macro_def(char *lbuf, int *j)
{
  int args=-1;
  int i,p;

  /* read mask, count parameters (and remember their name) */

  p=(*j);

  {
    int quoted=0;
    while ((!is_sep(lbuf[(*j)]))||quoted) 
      {
	if (lbuf[(*j)]=='\"')   /*"*/
	  {
	    quoted^=1;
	  }
	(*j)++;
      }
  }

  if (lbuf[(*j)]=='(') {
    lbuf[(*j)]=',';
    while (lbuf[i=nextchar(lbuf,(*j))]==',') {
      lbuf[(*j)]='\0';
      (*j)=nextchar(lbuf,i+1);
      if (lbuf[(*j)]=='\0') { 
        error("syntax"); return NO_MATCH; }
      if (args>=PARAMETERS_MAX) { 
        error("too many parameter"); return NO_MATCH; }
      mpar[++args]=&lbuf[(*j)];
      while (!is_sep(lbuf[(*j)])) (*j)++; }
    if (lbuf[i]!=')') error("syntax");
    lbuf[(*j)]='\0';
    (*j)=nextchar(lbuf,i+1); }
  else {
    if (lbuf[(*j)]!='\0') { 
      if (lbuf[(*j)]!=' ' && lbuf[(*j)]!='\t') { 
        error("syntax"); return NO_MATCH; }
      lbuf[(*j)]='\0'; 
      (*j)=nextchar(lbuf,(*j)+1); } }

  if (defcount>=DEFINES_MAX) { 
    error("too many defines"); return NO_MATCH; }
  parcount[defcount]=args+1;
  if (search_def(&lbuf[p])!=NO_MATCH) { 
    error("redefined macro"); return NO_MATCH; }

  defs[defcount]=str_sav(&lbuf[p]);

# ifdef debug
  printf("new macro with %i parameter:",args+1);

  i=0;
  while (i<=args) printf(" \"%s\"",mpar[i++]);
  printf("\n");
# endif

  return args;
}

void add_define(char *defname, char *replacement)
{
  defs[defcount]=defname;
  repl[defcount]=replacement;
  defcount++;
  if (defcount>=DEFINES_MAX)
    error("too many defines");
}

int main(int argc, char **argv)
{
  static int  i,j,p,tmp1,tmp2;
  static char lbuf[LINE_LENGTH_MAX];
  static char buf[100];
  static int  quiet_mode;
  static char *file_input;
  static char *file_output;
  static char *tmpstr;
  static FILE *outfile;
  static int  disable,depth;
  static int  if_flag[IF_DEPTH_MAX];
  static int  remove_spaces=1;
  static time_t bin_time;
  static struct tm *timeptr;

  file_input=file_output=NULL;
  quiet_mode=errors=disable=depth=0;
  if_flag[depth]=NO_MATCH;
  defcount=0;
  remove_remarks=1;
  add_dotLines=0;

  i=1;
  while ( i<argc ) {
    if (argv[i][0]=='-') {
      j=1;
      while (argv[i][j]!='\0') {
        switch (argv[i][j]) {
          case 'd': { 
            if (defcount>=DEFINES_MAX) { 
              error("too many defines\n"); 
              exit(1); }
            tmpstr=&argv[i][j+1];
            p=0;
            while (!is_sep(tmpstr[p])) p++;
            if (tmpstr[p]=='=') {
              tmpstr[p]='\0';
              defs[defcount]=str_sav(tmpstr);
              repl[defcount]=str_sav(&tmpstr[p+1]); }
            else if (tmpstr[p]=='\0') {
              defs[defcount]=str_sav(tmpstr);
              repl[defcount]=str_sav(""); }
            else Howto();
            defcount++;
            j=0; break; }
          case 'o': { i++; file_output=argv[i]; j=0; break; }
          case 'r': { remove_remarks=0; break; }
          case 's': { remove_spaces=0; break; }
          case 'l': { add_dotLines=1; break; }
          case 'q': { quiet_mode=1; break; }
          default:  Howto();
          }
        if (i==argc) Howto();
        if (j==0) break;
        j++; }
	} else {
      if (file_input!=NULL) Howto();
      file_input=argv[i]; pushSourceFile(file_input); }
    i++; }

  if (file_input==NULL) { printf("%s: No input file\n",argv[0]); exit(1); }
  if (file_output==NULL) file_output="lupo.out";

  outfile=fopen(file_output,"w");
  if (outfile==NULL) {
    printf("can't write to outputfile\n");
    exit(1); }
  line=0;
  infiles=0;
  infile=fopen(file_input,"r");
  if (infile==NULL) {
    printf("can't open inputfile\n");
    exit(1); }
  infilestream[0]=infile;
  infilename[0]=file_input;

  spec_label_count=0;
  spec_lab_stack_ptr=0;

  /* add some default defines */

  add_define("_LUPO_","");

  time(&bin_time);
  timeptr=localtime(&bin_time);
  strftime(buf,100,TIMEFORMAT,timeptr);
  add_define("_DATE_",str_sav(buf));
  
  /* start preprocessing input file */

  if (!quiet_mode) printf("Working...\n");

  while (readline(lbuf)!=EOF) {

#   ifdef debug
    printf("line=\"%s\" depth=%i, disable=%i, if_flag=%i\n",lbuf,depth,disable,if_flag[depth]);
#   endif

    i=nextchar(lbuf,0);
    if (lbuf[i]=='\0') continue;
    
    i=nextchar(lbuf,0);
    if (lbuf[i]=='#') {
    
      /* is a preprocessor directive */
    
      i=nextchar(lbuf,++i);
      if (lbuf[i]=='\0') continue; /* was NULL-directive */

      if ((j=match(lbuf,i,"if"))!=NO_MATCH ||
          (j=match(lbuf,i,"ifdef"))!=NO_MATCH ) {
        p=get_expr(lbuf,&j);
        if (lbuf[j]!='\0' && lbuf[j]!=';') error("syntax");
        depth++; 
        if (depth>=IF_DEPTH_MAX) {
          error("too deep if");
          exit(1); }
        if (!disable && !p) { 
           disable=depth;
           if_flag[depth]=0; }
        else if_flag[depth]=1;
        continue; }

      if ((j=match(lbuf,i,"elif"))!=NO_MATCH) {
        if (if_flag[depth]==NO_MATCH) { 
          error("elif without if");
          continue; }
        p=get_expr(lbuf,&j);
        if (lbuf[j]!='\0' && lbuf[j]!=';') error("syntax");
        p=if_flag[depth]==0 && p;
        if (!p && !disable) disable=depth;
        if (p && disable==depth) disable=0;
        if (p) if_flag[depth]=1;
        if (depth==0) error("elif without if");
        continue; }

      if ((j=match(lbuf,i,"ifndef"))!=NO_MATCH) {
        p=get_term(lbuf,&j);
        j=nextchar(lbuf,j);
        if (lbuf[j]!='\0' && lbuf[j]!=';') error("syntax");
        depth++;
        if (depth>=IF_DEPTH_MAX) {
          error("too deep if");
          exit(1); }
        if (p && !disable) {
          disable=depth;
          if_flag[depth]=0; }
        else if_flag[depth]=1;
        continue; }

      if ((j=match(lbuf,i,"else"))!=NO_MATCH) {
        j=nextchar(lbuf,j);
        if (lbuf[j]!='\0' && lbuf[j]!=';') error("syntax");
        if (depth==0 || if_flag[depth]==NO_MATCH) 
          error("else without if"); 
        else {
          if (if_flag[depth]==0) {
            disable=0;
            if_flag[depth]=1; }
          else if (!disable) disable=depth; }
        continue; }

      if ((j=match(lbuf,i,"endif"))!=NO_MATCH) {
        j=nextchar(lbuf,j);
        if (lbuf[j]!='\0' && lbuf[j]!=';') error("syntax");
        if (disable==depth) disable=0;
        if (depth==0) error("endif without if"); else {
          if_flag[depth]=NO_MATCH;
          depth--; }
        continue; }

      if ((j=match(lbuf,i,"enddef"))!=NO_MATCH) {
        error("enddef without begindef");
        continue; }

      if ((j=match(lbuf,i,"msg"))!=NO_MATCH) {
        if (!disable) printf("%s\n",&lbuf[nextchar(lbuf,j)]);
        continue; }

      if ((j=match(lbuf,i,"error"))!=NO_MATCH) {
        if (!disable) {
          error("preprocessing stopped");
          exit(1); }
        continue; }

      if ((j=match(lbuf,i,"include"))!=NO_MATCH) {
        if (disable) continue;

        j=nextchar(lbuf,j);
        process_line(&lbuf[j]);

        if (lbuf[j]=='\0') { error("missing filename"); continue; }
        if ((lbuf[j]!='\"')&&(lbuf[j]!='<'))            /*"*/
	    { error("'\"' or '<' expected"); continue; }
        i=++j;

        if (lbuf[i-1]=='<') lbuf[i-1]='>';
        while ((lbuf[j]!=lbuf[i-1]) && lbuf[j]!='\0') {
          j++; }
        if (lbuf[j]=='\0') error("unterminated filename in #include");
        lbuf[j]='\0';

        if (lbuf[i-1]=='\"') { /*"*/
          /* Local include */
          infile=fopen(&lbuf[i],"r");
          if (infile!=NULL)
            pushSourceFile(&lbuf[i]); }
        else
          /* System include */
          infile=fopenSystemInclude(&lbuf[i]);

        if (infile==NULL) {
          sprintf(buf,"can't open include file \"%s\"",&lbuf[i]);
          error(buf);
          infile=infilestream[infiles];
          continue; }

        lpos[infiles]=line;
        if (lbuf[nextchar(lbuf,j+1)]!='\0') error("syntax");
        infiles++;
        if (infiles>=INCLUDE_DEPTH_MAX) { 
	  infiles--;
	  error("too many nested includes"); 
 	  exit(1); }
        infilestream[infiles]=infile;
        infilename[infiles]=str_sav(&lbuf[i]);
        line=0;
        continue; }

      if ((j=match(lbuf,i,"undef"))!=NO_MATCH) {
        if (disable) continue;

        j=nextchar(lbuf,j);

        if (lbuf[j]=='\0') { error("missing argument"); continue; }

        p=j;
        while (!is_sep(lbuf[j])) j++;

        if (lbuf[j]!='\0') {
          i=nextchar(lbuf,j);
          if (lbuf[i]!='\0' && lbuf[i]!=';') { error("syntax"); continue; }
          lbuf[j]='\0'; }

        i=search_def(&lbuf[p]);
        if (i!=NO_MATCH) {
          free(defs[i]);
          free(repl[i]);
          defcount--;
          while (i<defcount) {
            parcount[i]=parcount[i+1];
            defs[i]=defs[i+1];
            repl[i]=repl[i+1];
            i++; }

#         ifdef debug
		  printf("removed!\n");
#         endif

          }
	    continue; }

      if ((j=match(lbuf,i,"define"))!=NO_MATCH ||
          (j=match(lbuf,i,"begindef"))!=NO_MATCH) {

        int args,flag;
        flag=(lbuf[i]=='b');

        if (disable) {

          if (flag) {
            /* search for #enddef */
            tmp2=0;
            while (readline(lbuf)!=EOF) {
              i=nextchar(lbuf,0);
              if (lbuf[i]!='#') continue;
              i=nextchar(lbuf,i+1);
              if ((j=match(lbuf,i,"enddef"))==NO_MATCH) {
                error("#directive in macro-definition");
                continue; }
              j=nextchar(lbuf,j);
              if (lbuf[j]!='\0' && lbuf[j]!=';') error("syntax");
              tmp2=1;
              break; }
            if (!tmp2) error("begindef without enddef"); }

            continue; }

        j=nextchar(lbuf,j);
        process_line(&lbuf[j]);
        if (lbuf[j]=='\0') { error("missing argument"); continue; }

        if ((args=read_macro_def(lbuf,&j))==NO_MATCH) continue;

        /* read replacement, and replace parameter by single ascii */

        if (!flag) {
          /* makro defined in this line */
          i=p=j;
          while (lbuf[j]!='\0') {
            if (!is_sep(lbuf[j])) {
              tmp1=0; tmp2=NO_MATCH;
              while (tmp1<=args) {
                if ((tmp2=match(lbuf,j,mpar[tmp1]))!=NO_MATCH) break;
                tmp1++; }
              if (tmp2!=NO_MATCH) {
                lbuf[i++]=(char) tmp1+2;
                j=tmp2; 
                continue; } }
            if (lbuf[j]>=' ' || lbuf[j]=='\1') lbuf[i++]=lbuf[j];
            else if (lbuf[j]=='\t') lbuf[i++]=' '; 
            j++; }

          lbuf[i]='\0';
          repl[defcount]=str_sav(&lbuf[p]); }

        else {
          /* makro defined in next lines, terminated with #enddef */
          char *lbuf2;

          i=nextchar(lbuf,j);
          if (lbuf[i]!='\0' && lbuf[i]!=';') error("syntax");
          tmpstr=malloc(MACRO_LENGTH_MAX+1);
          if (tmpstr==NULL) { error("out of memory"); exit(1); }

          tmp2=0; p=0;
          lbuf2=malloc(LINE_LENGTH_MAX);
          if (lbuf2==NULL) { error("out of memory"); exit(1); }

          while (readline(lbuf2)!=EOF) {
            i=nextchar(lbuf2,0);
            if (lbuf2[i]=='#') {
              i=nextchar(lbuf2,i+1);
              if ((j=match(lbuf2,i,"enddef"))!=NO_MATCH) {
                j=nextchar(lbuf2,j);
                if (lbuf2[j]!='\0' && lbuf2[j]!=';') error("syntax");
                tmp2=1;
                break; }
              else error("#directive in macro-definition"); }
            else {
              process_line(lbuf2);
              j=0;
              while (lbuf2[j]!='\0' && p<MACRO_LENGTH_MAX) {
                if (!is_sep(lbuf2[j])) {
                  tmp1=0; tmp2=NO_MATCH;
                  while (tmp1<=args) {
                    if ((tmp2=match(lbuf2,j,mpar[tmp1]))!=NO_MATCH) break;
                    tmp1++; }
                  if (tmp2!=NO_MATCH) {
                    tmpstr[p++]=(char) tmp1+2;
                    j=tmp2; 
                    continue; } }
                if (lbuf2[j]>=' ' || lbuf2[j]=='\1') tmpstr[p++]=lbuf2[j]; 
                else if (lbuf2[j]=='\t') tmpstr[p++]=' '; 
                j++; }
              tmp2=0; }
            if (p<MACRO_LENGTH_MAX) tmpstr[p++]=(char) 1; }

          free(lbuf2);
          if (!tmp2) error("begindef without enddef"); 

          if (p>0 && tmpstr[p-1]==(char) 1) p--;
          if (p>MACRO_LENGTH_MAX) {
            error("macro too long");
            p=MACRO_LENGTH_MAX; } 

          tmpstr[p]='\0';
          repl[defcount]=str_sav(tmpstr);
          free(tmpstr);
#         ifdef debug  
          printf("str_sav:"); macroout(repl[defcount]);
#         endif
          }
        
        defcount++;
        continue; } 

      sprintf(buf,"unknown directive \"%s\"",&lbuf[i]);
      error(buf);
      continue; }
    
    if (disable==0) {
      process_line(lbuf);
      process_line_spec(lbuf);
      i=0;
      if (remove_spaces) { 
        while (lbuf[i]==' ' || lbuf[i]=='\t') i++; }

      if (!remove_spaces || lbuf[i]!='\0') {
	if (add_dotLines)
	  {
	    fprintf(outfile,"\t.line %d%s\n",line,getSourceFile());
	  }
        while (lbuf[i]!='\0') {
          if (lbuf[i]==(char) 1) fprintf(outfile,"\n");
          else fputc(lbuf[i],outfile); 
          i++; }
        fprintf(outfile,"\n"); }
	  }
   }

   fclose(outfile);
   if (depth!=0) error("if without endif");
   if (spec_lab_stack_ptr!=0) error("non empty special stack at end of file");
   if (errors) {
     printf("summary: %i error(s)\n",errors);
     exit(1); }
   else { 
     if (!quiet_mode) printf("done, no errors\n"); 
     exit(0); }
}

char sf_name[INCLUDE_DEPTH_MAX][1024];
int sf_count=0;

int pushSourceFile(char *foo)
{
  strcpy(sf_name[sf_count],foo);
  sf_count++;
  return(0);
}

int popSourceFile()
{
  sf_count--;
  return(0);
}

char *getSourceFile()
{
  int i;

  /* Clear source pedigree string */
  sourcePedigree[0]=0;

  /* Build source pedigree list */
  for(i=sf_count;i>0;i--)
    {
      sprintf(sourcePedigree,"%s,%s",sourcePedigree,sf_name[i-1]);
    }

  return(sourcePedigree);
}

FILE *fopenSystemInclude(char *foo)
{
  FILE *boo;
  char temp[1024];

#ifdef USE_GETENV
  char *envtmp;

  envtmp=getenv("LUPO_INCLUDEPATH");
/*  printf("envtmp:%s\n\r",envtmp);*/
  if (envtmp!=NULL) {
    int i;

    while (1) {
      /* scan all paths in this string */
      i=0;
      while (envtmp[i]!='\0' && envtmp[i]!=PATH_SEPARATOR) i++;
      strncpy(temp,envtmp,i);
      temp[i]=DIRECTORY_SEPARATOR;
      strcpy(&temp[i+1],foo);
	  
/*	  printf("hh %s\n\r",temp);*/

      if ((boo=fopen(temp,"r"))!=NULL) {
        pushSourceFile(temp);
        return boo; }
      if (envtmp[i]!='\0') envtmp=&envtmp[i+1];
      else break; }

    return NULL; }

  error("environment varable \"LUPO_INCLUDEPATH\" is undefined");
  return NULL;

#else

  /* no getenv, then check some standard (UNIX) paths */

  sprintf(temp,"/usr/include/c64/%s",foo);
  if ((boo=fopen(temp,"r")))
    {
      pushSourceFile(temp);
      return(boo);
    }
  sprintf(temp,"/usr/include/lunix/%s",foo);
  if ((boo=fopen(temp,"r")))
    {
      pushSourceFile(temp);
      return(boo);
    }

  sprintf(temp,"/usr/local/include/c64/%s",foo);
  if ((boo=fopen(temp,"r")))
    {
      pushSourceFile(temp);
      return(boo);
    }
  sprintf(temp,"/usr/local/include/lunix/%s",foo);
  if ((boo=fopen(temp,"r")))
    {
      pushSourceFile(temp);
      return(boo);
    }

  sprintf(temp,"/usr/include/%s",foo);
  if ((boo=fopen(temp,"r")))
    {
      pushSourceFile(temp);
      return(boo);
    }

  sprintf(temp,"/usr/local/include/%s",foo);
  if ((boo=fopen(temp,"r")))
    {
      pushSourceFile(temp);
      return(boo);
    }

  /* Cant find it */
  return(NULL);

#endif 

}
