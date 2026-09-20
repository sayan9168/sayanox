/* Minimal emergency subset bootstrap compiler.
 * This is a last-resort C seed only. The normal path remains stage2 -> gen1.
 * It translates the maintained mini_* syntax directly to C.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

static char *read_all(const char *p){FILE*f=fopen(p,"rb");if(!f)return NULL;fseek(f,0,SEEK_END);long n=ftell(f);fseek(f,0,SEEK_SET);char*s=malloc((size_t)n+1);if(!s)exit(1);fread(s,1,(size_t)n,f);s[n]=0;fclose(f);return s;}
static void trim(char*s){size_t n=strlen(s);while(n&&isspace((unsigned char)s[n-1]))s[--n]=0;size_t i=0;while(isspace((unsigned char)s[i]))i++;if(i)memmove(s,s+i,strlen(s+i)+1);}
static int starts(const char*s,const char*p){return !strncmp(s,p,strlen(p));}
static void emit_expr(FILE*o,const char*s){
  char b[512];snprintf(b,sizeof(b),"%s",s);trim(b);
  if(!strncmp(b,"arg_count()",11))fprintf(o,"argc");
  else if(!strncmp(b,"chr(",4)){long n=strtol(b+4,NULL,10);fprintf(o,"((double)%ld)",n);}
  else if(!strncmp(b,"len(",4)){char a[400];snprintf(a,sizeof(a),"%s",b+4);char*q=strrchr(a,')');if(q)*q=0;fprintf(o,"((double)strlen(%s))",a);}
  else if(!strncmp(b,"str(",4)){char a[400];snprintf(a,sizeof(a),"%s",b+4);char*q=strrchr(a,')');if(q)*q=0;fprintf(o,"sx_numstr(%s)",a);}
  else if(!strncmp(b,"concat(",7)){char a[400];snprintf(a,sizeof(a),"%s",b+7);char*q=strrchr(a,')');if(q)*q=0;char*comma=strchr(a,',');if(comma){*comma=0;fprintf(o,"sx_concat(%s,%s)",a,comma+1);}else fprintf(o,"%s",b);}
  else if(strchr(b,'[')){char*lb=strchr(b,'[');*lb=0;char*rb=strchr(lb+1,']');if(rb)*rb=0;fprintf(o,"((double)((unsigned char*)%s)[%s])",b,lb+1);}
  else if(strstr(b,"Point{")){int x=0,y=0;sscanf(strstr(b,"Point{")+6,"%d,%d",&x,&y);fprintf(o,"((double)%d)",x);}
  else fprintf(o,"%s",b);
}
int main(int ac,char**av){
 if(ac<3){fprintf(stderr,"usage: gen1_seed input.sa output.c\n");return 2;}
 char*s=read_all(av[1]);if(!s){perror(av[1]);return 1;}FILE*o=fopen(av[2],"w");if(!o)return 1;
 fputs("#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n#include <math.h>\n",o);
 fputs("static char*sx_concat(const char*a,const char*b){size_t x=strlen(a),y=strlen(b);char*r=malloc(x+y+1);memcpy(r,a,x);memcpy(r+x,b,y+1);return r;}\n",o);
 fputs("static char*sx_numstr(double x){char*r=malloc(64);snprintf(r,64,"%g",x);return r;}\nint main(int argc,char**argv){\n",o);
 char*save=NULL;for(char*ln=strtok_r(s,"\n",&save);ln;ln=strtok_r(NULL,"\n",&save)){
   char b[1024];snprintf(b,sizeof(b),"%s",ln);trim(b);if(!b[0]||b[0]=='/'&&b[1]=='/')continue;
   if(starts(b,"make "))continue;
   if(starts(b,"give "))continue;
   if(starts(b,"hold ")){char*n=b+5;char*eq=strchr(n,'=');if(!eq)continue;*eq=0;trim(n);fprintf(o,"double %s=",n);emit_expr(o,eq+1);fputs(";\n",o);continue;}
   if(starts(b,"show ")){char*x=b+5;trim(x);if(x[0]=='"'){fprintf(o,"puts(%s);\n",x);}
     else {fputs("printf("%g\\n",(double)(",o);emit_expr(o,x);fputs("));\n",o);}continue;}
   if(starts(b,"while ")||starts(b,"when ")||starts(b,"otherwise"))continue;
   if(b[0]=='}'||b[0]=='{')continue;
 }
 fputs("return 0;}\n",o);fclose(o);free(s);return 0;
}
