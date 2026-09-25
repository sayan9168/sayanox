#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
static char *src; static int n, pos;
static void skip(void){ while(pos<n&&(src[pos]==' '||src[pos]=='\n'||src[pos]=='\t'))pos++; }
static int match(const char *k){ int L=(int)strlen(k); if(pos+L>n||strncmp(src+pos,k,L))return 0;
  if(pos+L<n&&(isalnum((unsigned char)src[pos+L])||src[pos+L]=='_'))return 0; return 1; }
int main(int argc,char **argv){
  if(argc<3){fprintf(stderr,"usage: sxc in.sa out.c\n");return 1;}
  FILE *f=fopen(argv[1],"rb"); if(!f)return 1; fseek(f,0,2); long sz=ftell(f); fseek(f,0,0);
  src=malloc((size_t)sz+1); n=(int)fread(src,1,(size_t)sz,f); src[n]=0; fclose(f); pos=0;
  FILE *o=fopen(argv[2],"wb");
  fputs("#include <stdio.h>\nint main(void){\n",o);
  while(pos<n){ skip(); if(pos>=n)break;
    if(match("hold")){ pos+=4; skip(); char name[64]; int i=0;
      while(pos<n&&i<63&&(isalnum((unsigned char)src[pos])||src[pos]=='_')) name[i++]=src[pos++];
      name[i]=0; skip(); if(src[pos]=='=')pos++; skip();
      if(isdigit((unsigned char)src[pos])){ double v=0; while(isdigit((unsigned char)src[pos])){v=v*10+(src[pos]-'0');pos++;}
        fprintf(o,"  double %s = %.0f;\n",name,v);
      } else { while(pos<n&&src[pos]!='\n')pos++; }
    } else if(match("show")){ pos+=4; skip();
      if(src[pos]=='"'){ pos++; char s[256]; int i=0; while(pos<n&&src[pos]!='"'&&i<255)s[i++]=src[pos++];
        if(src[pos]=='"')pos++; s[i]=0; fprintf(o,"  puts(\"%s\");\n",s);
      } else { char name[64]; int i=0; while(pos<n&&i<63&&(isalnum((unsigned char)src[pos])||src[pos]=='_'))name[i++]=src[pos++];
        name[i]=0; fprintf(o,"  printf(\"%%g\\n\",%s);\n",name); }
    } else pos++;
  }
  fputs("  return 0;\n}\n",o); fclose(o); printf("1\n"); return 0;
}
