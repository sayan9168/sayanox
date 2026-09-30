/* Sayanox native AOT — real Linux x86-64 machine code (not fold-only).
 * hold/show/when/while, ints, + - * /, comparisons, show "str"
 * Usage: native_aot in.sa out
 */
#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>

#define CMAX 65536
#define RMAX 4096

static unsigned char code[CMAX]; static size_t cn;
static char rodata[RMAX]; static size_t rn;

static void eb(unsigned char b){ if(cn>=CMAX){fprintf(stderr,"code OOM\n");exit(1);} code[cn++]=b; }
static void eu32(uint32_t v){ eb(v); eb(v>>8); eb(v>>16); eb(v>>24); }
static void eu64(uint64_t v){ for(int i=0;i<8;i++) eb((unsigned char)(v>>(8*i))); }
static void erel32(size_t at, size_t to){ int32_t d=(int32_t)(to-(at+4)); memcpy(code+at,&d,4); }

static void sw(const char**p){ while(**p&&isspace((unsigned char)**p)) (*p)++; }
static int id0(char c){ return isalpha((unsigned char)c)||c=='_'; }
static int id(char c){ return isalnum((unsigned char)c)||c=='_'; }
static int mkw(const char**p,const char*k){ size_t n=strlen(k); if(strncmp(*p,k,n)||id((*p)[n])) return 0; *p+=n; return 1; }
static int pid(const char**p,char*b,size_t c){ sw(p); if(!id0(**p)) return 0; size_t i=0; while(id(**p)&&i+1<c) b[i++]=*(*p)++; b[i]=0; return 1; }
static int pint(const char**p,long*o){ sw(p); if(!isdigit((unsigned char)**p)) return 0; long v=0; while(isdigit((unsigned char)**p)) v=v*10+(*(*p)++-'0'); *o=v; return 1; }
static int slot(const char*n){ unsigned char c=(unsigned char)n[0]; if(c>='A'&&c<='Z') c=(unsigned char)(c-'A'+'a'); return (c>='a'&&c<='z')?(c-'a')%26:0; }

static void emit_load_slot(int s){ int d=-8*(s+1); if(d>=-128){eb(0x48);eb(0x8b);eb(0x45);eb((unsigned char)d);}else{eb(0x48);eb(0x8b);eb(0x85);eu32((uint32_t)d);} }
static void emit_store_slot(int s){ int d=-8*(s+1); if(d>=-128){eb(0x48);eb(0x89);eb(0x45);eb((unsigned char)d);}else{eb(0x48);eb(0x89);eb(0x85);eu32((uint32_t)d);} }
static void emit_mov_imm(long v){ eb(0x48); eb(0xb8); eu64((uint64_t)(int64_t)v); }

static size_t itoa_off, wstr_off;
static size_t patch_itoa[128]; static int npi;
static size_t patch_wstr[128]; static int npw;
static size_t str_off[64]; static size_t str_len[64]; static int nst;

static void call_itoa(void){ eb(0xe8); if(npi>=128)exit(1); patch_itoa[npi++]=cn; eu32(0); }
static void call_wstr(void){ eb(0xe8); if(npw>=128)exit(1); patch_wstr[npw++]=cn; eu32(0); }

static int parse_prim(const char**p,int*e);
static int parse_term(const char**p,int*e);
static int parse_rel(const char**p,int*e);
static int parse_expr(const char**p,int*e);

static int parse_prim(const char**p,int*e){
  sw(p);
  if(**p=='('){ (*p)++; if(!parse_expr(p,e)) return 0; sw(p); if(**p!=')'){*e=1;return 0;} (*p)++; return 1; }
  if(**p=='-'){ (*p)++; if(!parse_prim(p,e)) return 0; eb(0x48); eb(0xf7); eb(0xd8); return 1; }
  long v=0; if(pint(p,&v)){ emit_mov_imm(v); return 1; }
  char n[64]; if(pid(p,n,64)){ emit_load_slot(slot(n)); return 1; }
  return 0;
}
static int parse_term(const char**p,int*e){
  if(!parse_prim(p,e)||*e) return 0;
  for(;;){ sw(p); char op=**p; if(op!='*'&&op!='/') break; (*p)++;
    eb(0x50); if(!parse_prim(p,e)||*e) return 0;
    eb(0x48); eb(0x89); eb(0xc1); eb(0x58);
    if(op=='*'){ eb(0x48); eb(0x0f); eb(0xaf); eb(0xc1); }
    else { eb(0x48); eb(0x99); eb(0x48); eb(0xf7); eb(0xf9); }
  }
  return 1;
}
static int parse_rel(const char**p,int*e){
  if(!parse_term(p,e)||*e) return 0;
  for(;;){ sw(p); char op=**p; if(op!='+'&&op!='-') break; (*p)++;
    eb(0x50); if(!parse_term(p,e)||*e) return 0;
    eb(0x48); eb(0x89); eb(0xc1); eb(0x58);
    if(op=='+'){ eb(0x48); eb(0x01); eb(0xc8); } else { eb(0x48); eb(0x29); eb(0xc8); }
  }
  return 1;
}
static int parse_expr(const char**p,int*e){
  if(!parse_rel(p,e)||*e) return 0;
  sw(p);
  unsigned char sc=0; int tw=0;
  if((*p)[0]=='='&&(*p)[1]=='='){ sc=0x94; tw=1; }
  else if((*p)[0]=='!'&&(*p)[1]=='='){ sc=0x95; tw=1; }
  else if((*p)[0]=='<'&&(*p)[1]=='='){ sc=0x9e; tw=1; }
  else if((*p)[0]=='>'&&(*p)[1]=='='){ sc=0x9d; tw=1; }
  else if(**p=='<') sc=0x9c;
  else if(**p=='>') sc=0x9f;
  else return 1;
  *p += tw?2:1;
  eb(0x50); if(!parse_rel(p,e)||*e) return 0;
  eb(0x48); eb(0x89); eb(0xc1); eb(0x58);
  eb(0x48); eb(0x39); eb(0xc8);
  eb(0x0f); eb(sc); eb(0xc0);
  eb(0x48); eb(0x0f); eb(0xb6); eb(0xc0);
  return 1;
}

static int pstr(const char**p,char*buf,size_t cap,size_t*len){
  sw(p); if(**p!='"') return 0; (*p)++; size_t i=0;
  while(**p&&**p!='"'){ char c=*(*p)++; if(c=='\\'&&**p){ char x=*(*p)++; if(x=='n')c='\n'; else if(x=='t')c='\t'; else c=x; }
    if(i+1<cap) buf[i++]=c; }
  if(**p=='"') (*p)++; buf[i]=0; *len=i; return 1;
}

static void eblk(const char**p,int*e);
static void estmt(const char**p,int*e){
  sw(p); if(!**p||**p=='}') return;
  if(mkw(p,"hold")){
    char n[64]; if(!pid(p,n,64)){*e=1;return;} sw(p); if(**p!='='){*e=1;return;} (*p)++;
    if(!parse_expr(p,e)||*e){*e=1;return;} emit_store_slot(slot(n)); return;
  }
  if(mkw(p,"show")){
    sw(p); char sb[512]; size_t sl=0;
    if(pstr(p,sb,sizeof sb,&sl)){
      if(rn+sl>=RMAX){fprintf(stderr,"rodata\n");exit(1);}
      str_off[nst]=rn; str_len[nst]=sl; memcpy(rodata+rn,sb,sl); rn+=sl; nst++;
      emit_mov_imm((long)(nst-1)); call_wstr(); return;
    }
    if(!parse_expr(p,e)||*e){*e=1;return;}
    call_itoa(); return;
  }
  if(mkw(p,"when")){
    if(!parse_expr(p,e)||*e){*e=1;return;}
    eb(0x48); eb(0x85); eb(0xc0);
    eb(0x0f); eb(0x84); size_t jz=cn; eu32(0);
    sw(p); if(**p!='{'){*e=1;return;} (*p)++; eblk(p,e);
    sw(p);
    if(mkw(p,"otherwise")){
      eb(0xe9); size_t jend=cn; eu32(0); erel32(jz,cn);
      sw(p); if(**p!='{'){*e=1;return;} (*p)++; eblk(p,e); erel32(jend,cn);
    } else erel32(jz,cn);
    return;
  }
  if(mkw(p,"while")){
    size_t loop=cn;
    if(!parse_expr(p,e)||*e){*e=1;return;}
    eb(0x48); eb(0x85); eb(0xc0);
    eb(0x0f); eb(0x84); size_t jz=cn; eu32(0);
    sw(p); if(**p!='{'){*e=1;return;} (*p)++; eblk(p,e);
    eb(0xe9); size_t jb=cn; eu32(0); erel32(jb,loop);
    erel32(jz,cn);
    return;
  }
  if((*p)[0]=='/'&&(*p)[1]=='/'){ while(**p&&**p!='\n')(*p)++; return; }
  if(**p) (*p)++;
}
static void eblk(const char**p,int*e){
  while(**p&&**p!='}'&&!*e){ const char*b=*p; estmt(p,e); if(*p==b&&**p&&**p!='}') (*p)++; sw(p); }
  if(**p=='}') (*p)++;
}

static void emit_itoa_write(void){
  /* rax = signed value; write decimal + newline to fd 1 */
  itoa_off=cn;
  eb(0x48); eb(0x89); eb(0xc1); /* mov rcx, rax */
  eb(0x48); eb(0x83); eb(0xec); eb(0x28);
  eb(0x48); eb(0x8d); eb(0x74); eb(0x24); eb(0x27);
  eb(0xc6); eb(0x06); eb(0x0a);
  eb(0x49); eb(0xc7); eb(0xc0); eu32(0);
  eb(0x48); eb(0x85); eb(0xc9);
  eb(0x0f); eb(0x89); size_t jns=cn; eu32(0);
  eb(0x49); eb(0xc7); eb(0xc0); eu32(1);
  eb(0x48); eb(0xf7); eb(0xd9);
  size_t pos=cn; erel32(jns,pos);
  eb(0x48); eb(0x85); eb(0xc9);
  eb(0x0f); eb(0x85); size_t jnz_dig=cn; eu32(0);
  eb(0x48); eb(0xff); eb(0xce);
  eb(0xc6); eb(0x06); eb(0x30);
  eb(0xe9); size_t jmp_w=cn; eu32(0);
  size_t dig=cn; erel32(jnz_dig,dig);
  size_t loop=cn;
  eb(0x48); eb(0x31); eb(0xd2);
  eb(0x48); eb(0x89); eb(0xc8);
  eb(0x49); eb(0xc7); eb(0xc1); eu32(10);
  eb(0x49); eb(0xf7); eb(0xf1);
  eb(0x48); eb(0x89); eb(0xc1);
  eb(0x80); eb(0xc2); eb(0x30);
  eb(0x48); eb(0xff); eb(0xce);
  eb(0x88); eb(0x16);
  eb(0x48); eb(0x85); eb(0xc9);
  eb(0x0f); eb(0x85); size_t jnz=cn; eu32(0); erel32(jnz,loop);
  eb(0x4d); eb(0x85); eb(0xc0);
  eb(0x0f); eb(0x84); size_t jz_s=cn; eu32(0);
  eb(0x48); eb(0xff); eb(0xce);
  eb(0xc6); eb(0x06); eb(0x2d);
  size_t wr=cn; erel32(jz_s,wr); erel32(jmp_w,wr);
  eb(0x48); eb(0x8d); eb(0x54); eb(0x24); eb(0x28);
  eb(0x48); eb(0x29); eb(0xf2);
  eb(0x48); eb(0xc7); eb(0xc0); eu32(1);
  eb(0x48); eb(0xc7); eb(0xc7); eu32(1);
  eb(0x0f); eb(0x05);
  eb(0x48); eb(0x83); eb(0xc4); eb(0x28);
  eb(0xc3);
}

static void emit_wstr(void){
  wstr_off=cn;
  eb(0x50); eb(0x51); eb(0x52); eb(0x56); eb(0x57);
  eb(0x48); eb(0x89); eb(0xc1);
  eb(0x48); eb(0x8d); eb(0x1d); size_t tab_rel=cn; eu32(0);
  eb(0x48); eb(0xc1); eb(0xe1); eb(0x03);
  eb(0x48); eb(0x01); eb(0xcb);
  eb(0x8b); eb(0x33);
  eb(0x8b); eb(0x53); eb(0x04);
  eb(0x48); eb(0xbf); size_t ro_patch=cn; eu64(0);
  eb(0x48); eb(0x01); eb(0xfe);
  eb(0x48); eb(0xc7); eb(0xc0); eu32(1);
  eb(0x48); eb(0xc7); eb(0xc7); eu32(1);
  eb(0x0f); eb(0x05);
  eb(0x48); eb(0x83); eb(0xec); eb(0x08);
  eb(0xc6); eb(0x04); eb(0x24); eb(0x0a);
  eb(0x48); eb(0x89); eb(0xe6);
  eb(0x48); eb(0xc7); eb(0xc2); eu32(1);
  eb(0x48); eb(0xc7); eb(0xc0); eu32(1);
  eb(0x48); eb(0xc7); eb(0xc7); eu32(1);
  eb(0x0f); eb(0x05);
  eb(0x48); eb(0x83); eb(0xc4); eb(0x08);
  eb(0x5f); eb(0x5e); eb(0x5a); eb(0x59); eb(0x58);
  eb(0xc3);
  size_t table=cn; erel32(tab_rel, table);
  for(int i=0;i<nst;i++){ eu32((uint32_t)str_off[i]); eu32((uint32_t)str_len[i]); }
  (void)ro_patch;
}

#pragma pack(push,1)
typedef struct{unsigned char i[16];uint16_t t,m;uint32_t v;uint64_t e,ph,sh;uint32_t f;uint16_t eh,ps,pn,ss,sn,si;}EH;
typedef struct{uint32_t t,f;uint64_t o,va,pa,fs,ms,a;}PH;
#pragma pack(pop)

static void write_elf(const char*path){
  const uint64_t BASE=0x400000;
  size_t hdr=sizeof(EH)+sizeof(PH);
  size_t code_off=hdr;
  size_t rod_off=code_off+cn;
  size_t filesz=rod_off+rn;
  uint64_t code_va=BASE+code_off;
  uint64_t rod_va=BASE+rod_off;
  for(int i=0;i<npi;i++) erel32(patch_itoa[i], itoa_off);
  for(int i=0;i<npw;i++) erel32(patch_wstr[i], wstr_off);
  for(size_t i=wstr_off;i+10<cn;i++){
    if(code[i]==0x48 && code[i+1]==0xbf){ uint64_t v=rod_va; memcpy(code+i+2,&v,8); break; }
  }
  EH eh; memset(&eh,0,sizeof eh);
  eh.i[0]=0x7f; eh.i[1]='E'; eh.i[2]='L'; eh.i[3]='F'; eh.i[4]=2; eh.i[5]=1; eh.i[6]=1;
  eh.t=2; eh.m=62; eh.v=1; eh.e=code_va; eh.ph=sizeof(EH); eh.eh=sizeof(EH); eh.ps=sizeof(PH); eh.pn=1;
  PH ph; memset(&ph,0,sizeof ph);
  ph.t=1; ph.f=5; ph.o=0; ph.va=BASE; ph.pa=BASE; ph.fs=filesz; ph.ms=filesz; ph.a=0x1000;
  FILE*o=fopen(path,"wb");
  fwrite(&eh,1,sizeof eh,o); fwrite(&ph,1,sizeof ph,o);
  fwrite(code,1,cn,o); if(rn) fwrite(rodata,1,rn,o);
  fclose(o); chmod(path,0755);
}

static char*rf(const char*p,size_t*n){
  FILE*f=fopen(p,"rb"); if(!f){perror(p);exit(1);}
  fseek(f,0,SEEK_END); long N=ftell(f); fseek(f,0,SEEK_SET);
  char*b=malloc((size_t)N+1); if(fread(b,1,(size_t)N,f)!=(size_t)N){} b[N]=0; fclose(f); *n=(size_t)N; return b;
}

int main(int argc,char**argv){
  if(argc<3){ fprintf(stderr,"Usage: native_aot <in.sa> <out>\n"); return 1; }
  size_t n; char*s=rf(argv[1],&n);
  eb(0x55);
  eb(0x48); eb(0x89); eb(0xe5);
  eb(0x48); eb(0x81); eb(0xec); eu32(26*8);
  for(int i=0;i<26;i++){ emit_mov_imm(0); emit_store_slot(i); }
  int e=0; const char*p=s;
  while(*p&&!e){ sw(&p); if(!*p) break; const char*b=p; estmt(&p,&e); if(p==b&&*p) p++; }
  free(s);
  if(e){ fprintf(stderr,"native_aot: parse error\n"); return 1; }
  eb(0x48); eb(0xc7); eb(0xc0); eu32(60);
  eb(0x48); eb(0x31); eb(0xff);
  eb(0x0f); eb(0x05);
  emit_itoa_write();
  emit_wstr();
  write_elf(argv[2]);
  printf("native_aot: %s -> %s (real x86-64, %zu code bytes, no clang)\n", argv[1], argv[2], cn);
  return 0;
}
