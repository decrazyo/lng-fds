/* acon - assembler consistency checker */

#include <stdlib.h>
#include <stdio.h>
#include <ctype.h>
#include <string.h>

#define BUF_LEN 1024

int eat_spaces(int);
int str_chk(char*, int);
char *get_id(int);
char *str_dup(char*);
char *add_str(char*, const char*);
void print_str(char*);

char buf[BUF_LEN];
char idbuf[BUF_LEN];

#define REPL(str1,str2) {if(str1)free(str1);str1=str2;}

int eat_spaces(int i)
{
  while (i<BUF_LEN && (buf[i]==' ' || buf[i]=='\t')) i++;
  if (i>=BUF_LEN) return -1;
  if (buf[i]=='\n' || buf[i]=='\0') return -1;

  return i;
}

int str_chk(char *string, int i)
{
  int j;
  
  i=eat_spaces(i);
  if (i<0) return -1;

  j=0;
  while (string[j] && i+j<BUF_LEN && buf[i+j]==string[j]) j++;
  if (string[j]=='\0') return i+j;
  if (i+j>=BUF_LEN) return -1;
  return -1;
}

char *get_id(int i)
{
  int j;

  i=eat_spaces(i);
  if (i<0) return 0;

  j=0;
  while ( i+j<BUF_LEN && buf[i+j] ) {
	if (!isgraph(buf[i+j])) break;
	idbuf[j]=buf[i+j]; j++; }

  idbuf[j]='\0';
  return idbuf;  
}

char *str_dup(char *string)
{
  char *ctmp;

  ctmp=(char*) malloc(sizeof(char)*(strlen(string)+1));
  if (!ctmp) {
	printf("out of memory\n");
	exit(-1); }
  
  strcpy(ctmp,string);
  return ctmp;
}

char *
add_str(char *str1, const char *str2)
{
  int l1,l2;
  char *ctmp;

  if (str1) l1=strlen(str1); else l1=0;
  l2=strlen(str2);

  ctmp=(char*)malloc(sizeof(char)*(l1+l2+1));

  if (!ctmp) {
	printf("out of memory\n");
	exit(-1); }

  if (str1) strcpy(ctmp,str1);
  strcpy(&ctmp[l1],str2);
  return ctmp;
}

void
print_str(char *string)
{
  int i;

  if (!string)
	return;

  i=0;
  while (string[i]) {
	if (string[i]=='\n') {
	  if (string[i+1]!='\0')
		fputc(',',stdout);
	}
	else fputc(string[i],stdout);
	i++;
  }
}

struct dentry {
  char * function;
  char * in_list;
  char * out_list;
  char * comment;
  char * calls;
  char * changes;
  struct dentry * next;
};

int
main(int argc, char ** argv)
{
  int anum;
  char *ctmp;
  int i;
  int flag;
  int state1;
  FILE *inf;
  struct dentry *etmp;
  struct dentry *eroot;
  struct dentry *elast;

  anum=1;
  state1=0;
  eroot=0;
  elast=0;
  etmp=0;

  while (anum<argc) {
#ifdef DEBUG
	printf("reading file %s\n",argv[anum]);
#endif
	inf=fopen(argv[anum],"r");
	if (!inf) {
	  printf("error opening file\n");
	  printf("warning: file \"%s\" skipped\n",argv[anum]);
	  continue; }

	while (fgets(buf,BUF_LEN,inf)) {

	  /* ignore empty lines */
	  if ((i=eat_spaces(0))<0) continue;

	  switch (state1) {
	  case 0: {
		/* wait for new function header */
		if ((i=str_chk(";;",i))<0) break;
		if ((i=str_chk("function:",i))>0) {
		  ctmp=get_id(i);
		  etmp=(struct dentry*) malloc(sizeof(struct dentry));
		  if (!etmp) {
			printf("out of memory\n");
			exit(1); }
		  etmp->function=str_dup(ctmp);
		  etmp->in_list=0;
		  etmp->out_list=0;
		  etmp->comment=0;
		  etmp->changes=0;
		  etmp->calls=0;
		  etmp->next=0;
		  state1=1;
		}
		break;
	  }
	  case 1: {
		/* read rest of function header */
		if ((i=str_chk(";;",i))<0) {
		  /* end of function header reached */
#ifdef DEBUG
		  printf("==> add function\n");
		  printf("    name    =%s\n",etmp->function);
/* 		  printf("    inputs  =%s\n",etmp->in_list); */
/* 		  printf("    outputs =%s\n",etmp->out_list); */
/* 		  printf("    comment =%s\n",etmp->comment); */
		  printf("    calls   =%s\n",etmp->calls);
		  printf("    changes =%s\n",etmp->changes);
#endif
		  if (elast) elast->next=etmp;
		  else eroot=etmp;
		  elast=etmp;
		  state1=0;
		}
		else {
		  int k;
		  if ((k=str_chk("<",i))>0) {
			/* add to in_list */
			ctmp=add_str(etmp->in_list,&buf[k]);
			REPL(etmp->in_list,ctmp);
			break; }
		  if ((k=str_chk(">",i))>0) {
			/* add to out_list */
			ctmp=add_str(etmp->out_list,&buf[k]);
			REPL(etmp->out_list,ctmp);
			break; }
		  if ((k=str_chk("calls:",i))>0) {
			/* add to calls */
			ctmp=get_id(k);
			k=strlen(ctmp);
			ctmp[k]='\n';
			ctmp[k+1]=0;
			ctmp=add_str(etmp->calls,ctmp);
			REPL(etmp->calls,ctmp);
			break; }
		  if ((k=str_chk("changes:",i))>0) {
			/* add to changes */
			ctmp=get_id(k);
			k=strlen(ctmp);
			ctmp[k]='\n';
			ctmp[k+1]=0;
			ctmp=add_str(etmp->changes,ctmp);
			REPL(etmp->changes,ctmp);
			break; }
		  /* add to comment */
		  ctmp=add_str(etmp->comment,&buf[i]);
		  REPL(etmp->comment,ctmp);
		}
		break;
	  }
	  default: ;
	  }
	}
	fclose(inf);
	anum++;
  }

  /* expand all elements in changes sections */
  etmp=eroot;
  while (etmp) {
	int bp;
	int l,k;
	bp=0;
	ctmp=etmp->changes;
	if (ctmp) {
#ifdef DEBUG
	  printf("\"%s\" expands to\n",ctmp);
#endif
	  while (*ctmp) {
		i=0;
		while (ctmp[i]!='\n' && ctmp[i]!='(') i++;
		k=i;
		if (ctmp[i]!='\n') {
		  while (ctmp[i]!=')') {
			i++;
			for (l=0; l<k; l++) buf[bp++]=ctmp[l];
			while (isalnum(ctmp[i]))
			  buf[bp++]=ctmp[i++];
			buf[bp++]='\n'; }
		  i++; }
		else {
		  for (l=0; l<k; l++) buf[bp++]=ctmp[l];
		  buf[bp++]='\n'; }
		ctmp=&ctmp[i+1]; }

	  buf[bp]='\0';
#ifdef DEBUG
	  printf("\"%s\"\n",buf);
#endif
	  ctmp=str_dup(buf);
	  REPL(etmp->changes,ctmp);
	}
	etmp=etmp->next;
  }

  /* expand all calls */
  flag=1;
  while (flag) {
	int k,l;
	
#ifdef DEBUG
	printf("<--- new pass --->\n");
#endif

	flag=0;
	etmp=eroot;
	while (etmp) {
	  char calls_buf[BUF_LEN];
	  char changes_buf[BUF_LEN];
	  char ch_tmp[32];
	  char ca_tmp[32];
	  int calls_bp;
	  int changes_bp;

#ifdef DEBUG
	  printf("working on %s\n",etmp->function);
#endif

	  if (etmp->changes) {
		strcpy(changes_buf,etmp->changes);
		changes_bp=strlen(changes_buf);
	  } else {
		*changes_buf=0;
		changes_bp=0; }
		
	  *calls_buf=0;
	  calls_bp=0;
	  
	  ctmp=etmp->calls;
	  while (ctmp && *ctmp) {
		struct dentry *etmp2;

		i=0;
		while (ctmp[i]!='\n') { 
		  ca_tmp[i]=ctmp[i];
		  i++; }
		ca_tmp[i]='\0';
		ctmp=&ctmp[i+1];
#ifdef DEBUG
		printf("examine \"%s\"\n",ca_tmp);
#endif
		etmp2=eroot;
		while (etmp2) {
		  if (!strcmp(etmp2->function,ca_tmp) && etmp2->calls==0) {
			char *ctmp2;
			char *ctmp3;

#ifdef DEBUG
			printf("expanding function %s for %s\n",ca_tmp,etmp->function);
#endif
			ctmp2=etmp2->changes;
			while (ctmp2 && *ctmp2) {
			  int flag2;

			  k=0;
			  while (ctmp2[k]!='\n') { 
				ch_tmp[k]=ctmp2[k];
				k++; }
			  ch_tmp[k]='\0';


			  ctmp3=changes_buf;
			  flag2=0;
			  while (*ctmp3) {
				l=0;
				while (ch_tmp[l] && ch_tmp[l]==ctmp3[l]) l++;
				if (!ch_tmp[l] && ctmp3[l]=='\n') {
				  printf("warning: %s->%s might cause inconsistency in %s\n",
						 etmp->function, ca_tmp, ch_tmp);
				  flag2=1;
				}
				while (*ctmp3++!='\n');
			  }

			  if (!flag2) {
				/* adding changes */
				printf("  <= %s\n",ch_tmp);
				l=0;
				while (ch_tmp[l])
				  changes_buf[changes_bp++]=ch_tmp[l++];				  
				changes_buf[changes_bp++]='\n';
				changes_buf[changes_bp]=0;
			  }
			  ctmp2=&ctmp2[k+1];
			}
		    flag=1;
			break;
		  }
		  etmp2=etmp2->next;
		}
		if (!etmp2) {
		  /* function has not been expanded, so keep its name in the list */
		  i=0;
		  while (ca_tmp[i])
			calls_buf[calls_bp++]=ca_tmp[i++];
		  calls_buf[calls_bp++]='\n';
		  calls_buf[calls_bp]=0;
		}
	  }

	  if (etmp->calls) 
		free(etmp->calls);

	  if (calls_buf[0])
		etmp->calls=str_dup(calls_buf);
	  else
		etmp->calls=0;


	  if (etmp->changes) 
		free(etmp->changes);

	  if (changes_buf[0])
		etmp->changes=str_dup(changes_buf);
	  else
		etmp->changes=0;

	  etmp=etmp->next;
	}
  }

  /* dump results */

  printf("\nSummary\n=======\n");

  etmp=eroot;
  while (etmp) {
	printf("\n Name    = %s",etmp->function);
  printf("\n inputs  = %s",etmp->in_list); 
  printf("\n outputs = %s",etmp->out_list); 
  printf("\n comment = %s",etmp->comment); 
	printf("\n Changes = "); print_str(etmp->changes);
	if (etmp->calls) 
	  printf("\n Unresolved calls = "); print_str(etmp->calls);
	printf("\n");
	etmp=etmp->next;
  }

  return 0;
}
