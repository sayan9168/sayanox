/* Sayanox native AOT step2 — Linux x86_64 ELF, no clang for output.
   hold/show/when/while + ints. Usage: native_aot in.sa out */
#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#define OC 8192
#define IT 10000
static char*rf(const char*p,size_t*n){FILE*f=fopen(p,"rb");if(!f){perror(p);exit(1);}fseek(f,0,SEEK_END);long N=ftell(f);fseek(f,0,SEEK_SET);char*b=malloc((size_t)N+1);fread(b,1,(size_t)N,f);b[N]=0;fclose(f);*n=(size_t)N;return b;}
static void sw(const char**p){while(**p&&isspace((unsigned char)**p))(*p)++;}
static int id0(char c){return isalpha((unsigned char)c)||c=='_';}
static int id(char c){return isalnum((unsigned char)c)||c=='_';}
static int slot(const char*n){unsigned char c=(unsigned char)n[0];if(c>='A'&&c<='Z')c=(unsigned char)(c-'A'+'a');return (c>='a'&&c<='z')?(c-'a')%8:0;}
static int mkw(const char**p,const char*k){size_t n=strlen(k);if(strncmp(*p,k,n)||id((*p)[n]))return 0;*p+=n;return 1;}
static int pid(const char**p,char*b,size_t c){sw(p);if(!id0(**p))return 0;size_t i=0;while(id(**p)&&i+1<c)b[i++]=*(*p)++;b[i]=0;return 1;}
static int pint(const char**p,long*o){sw(p);if(!isdigit((unsigned char)**p))return 0;long v=0;while(isdigit((unsigned char)**p))v=v*10+(*(*p)++-'0');*o=v;return 1;}
static void an(char*o,size_t*op,size_t cap,long v){char t[32];int n=snprintf(t,32,"%ld\n",v);if(n>0&&*op+(size_t)n<cap){memcpy(o+*op,t,(size_t)n);*op+=(size_t)n;}}
static void eblk(const char**p,long*V,char*o,size_t*op,size_t cap,int*e);
static void skipb(const char**p){int d=1;while(**p&&d){if(**p=='{')d++;else if(**p=='}')d--;if(d)(*p)++;}if(**p=='}')(*p)++;}
static void estmt(const char**p,long*V,char*o,size_t*op,size_t cap,int*e){
 sw(p);if(!**p||**p=='}')return;
 if(mkw(p,"hold")){char n[64];long v;if(!pid(p,n,64)){*e=1;return;}sw(p);if(**p!='='){*e=1;return;}(*p)++;if(!pint(p,&v)){*e=1;return;}V[slot(n)]=v;return;}
 if(mkw(p,"show")){sw(p);long v;char n[64];if(pint(p,&v)){an(o,op,cap,v);return;}if(pid(p,n,64)){an(o,op,cap,V[slot(n)]);return;}*e=1;return;}
 if(mkw(p,"when")){char n[64];long cnd=0;sw(p);if(pint(p,&cnd)){}else if(pid(p,n,64))cnd=V[slot(n)];else{*e=1;return;}sw(p);if(**p!='{'){*e=1;return;}(*p)++;
  if(cnd)eblk(p,V,o,op,cap,e);else skipb(p);
  sw(p);if(mkw(p,"otherwise")){sw(p);if(**p!='{'){*e=1;return;}(*p)++;if(!cnd)eblk(p,V,o,op,cap,e);else skipb(p);}return;}
 if(mkw(p,"while")){char n[64];int un=0;long lit=0;sw(p);if(pint(p,&lit))un=0;else if(pid(p,n,64))un=1;else{*e=1;return;}sw(p);if(**p!='{'){*e=1;return;}
  const char*body=*p+1;const char*sc=body;int d=1;while(*sc&&d){if(*sc=='{')d++;else if(*sc=='}')d--;if(d)sc++;}
  int it=0;while(it++<IT){long cnd=un?V[slot(n)]:lit;if(!cnd)break;const char*bp=body;eblk(&bp,V,o,op,cap,e);if(*e)return;if(!un)break;}
  *p=sc;if(**p=='}')(*p)++;return;}
 if((*p)[0]=='/'&&(*p)[1]=='/'){while(**p&&**p!='\n')(*p)++;return;}
 if(**p)(*p)++;
}
static void eblk(const char**p,long*V,char*o,size_t*op,size_t cap,int*e){while(**p&&**p!='}'&&!*e){const char*b=*p;estmt(p,V,o,op,cap,e);if(*p==b&&**p&&**p!='}')(*p)++;sw(p);}if(**p=='}')(*p)++;}
static int eval(const char*src,char*o,size_t cap,size_t*ol){long V[8]={0};size_t op=0;int e=0;const char*p=src;while(*p&&!e){sw(&p);if(!*p)break;const char*b=p;estmt(&p,V,o,&op,cap,&e);if(p==b&&*p)p++;}*ol=op;return e;}
#pragma pack(push,1)
typedef struct{unsigned char i[16];uint16_t t,m;uint32_t v;uint64_t e,ph,sh;uint32_t f;uint16_t eh,ps,pn,ss,sn,si;}EH;
typedef struct{uint32_t t,f;uint64_t o,va,pa,fs,ms,a;}PH;
#pragma pack(pop)
static void elf(const char*path,const char*msg,size_t ml){
 const uint64_t B=0x400000;size_t hdr=sizeof(EH)+sizeof(PH);unsigned char c[64];size_t n=0;
 c[n++]=0x48;c[n++]=0xc7;c[n++]=0xc0;c[n++]=1;c[n++]=0;c[n++]=0;c[n++]=0;
 c[n++]=0x48;c[n++]=0xc7;c[n++]=0xc7;c[n++]=1;c[n++]=0;c[n++]=0;c[n++]=0;
 size_t ld=n+3;c[n++]=0x48;c[n++]=0x8d;c[n++]=0x35;c[n++]=0;c[n++]=0;c[n++]=0;c[n++]=0;
 c[n++]=0x48;c[n++]=0xc7;c[n++]=0xc2;uint32_t m=(uint32_t)ml;memcpy(c+n,&m,4);n+=4;c[n++]=0x0f;c[n++]=0x05;
 c[n++]=0x48;c[n++]=0xc7;c[n++]=0xc0;c[n++]=0x3c;c[n++]=0;c[n++]=0;c[n++]=0;c[n++]=0x48;c[n++]=0x31;c[n++]=0xff;c[n++]=0x0f;c[n++]=0x05;
 size_t co=hdr,mo=co+n,fs=mo+ml;int32_t d=(int32_t)((B+mo)-(B+co+ld+4));memcpy(c+ld,&d,4);
 EH eh;memset(&eh,0,sizeof eh);eh.i[0]=0x7f;eh.i[1]='E';eh.i[2]='L';eh.i[3]='F';eh.i[4]=2;eh.i[5]=1;eh.i[6]=1;
 eh.t=2;eh.m=62;eh.v=1;eh.e=B+co;eh.ph=sizeof(EH);eh.eh=sizeof(EH);eh.ps=sizeof(PH);eh.pn=1;
 PH ph;memset(&ph,0,sizeof ph);ph.t=1;ph.f=5;ph.va=B;ph.pa=B;ph.fs=fs;ph.ms=fs;ph.a=0x1000;
 FILE*o=fopen(path,"wb");fwrite(&eh,1,sizeof eh,o);fwrite(&ph,1,sizeof ph,o);fwrite(c,1,n,o);fwrite(msg,1,ml,o);fclose(o);chmod(path,0755);
}
int main(int argc,char**argv){
 if(argc<3){fprintf(stderr,"Usage: native_aot <in.sa> <out>\n");return 1;}
 size_t n;char*s=rf(argv[1],&n);char o[OC];size_t ol=0;int e=eval(s,o,OC,&ol);free(s);
 if(e||!ol){fprintf(stderr,"native_aot: no output\n");return 1;}
 elf(argv[2],o,ol);printf("native_aot: %s -> %s (%zu bytes, no clang)\n",argv[1],argv[2],ol);return 0;
}
