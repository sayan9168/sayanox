/* SX_EMIT_LOG -> analysis listing. Not an executable IR or a second backend.
 * C99, streaming one dynamically sized line at a time; no interpreter needed.
 * Unknown instructions are uppercased, unknown lines retained as comments.
 * Licensed under Sayanox License v1.1 (see LICENSE).
 */
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

typedef struct { const char *from, *to; } Pair;
static const Pair regs[] = {
  {"rax","A"},{"eax","A"},{"al","A"},{"rcx","C"},{"ecx","C"},{"cl","C"},
  {"rdx","D"},{"edx","D"},{"dl","D"},{"rbx","B"},{"ebx","B"},{"bl","B"},
  {"rsi","SI"},{"esi","SI"},{"sil","SI"},{"rdi","DI"},{"edi","DI"},{"dil","DI"},
  {"rsp","SP"},{"esp","SP"},{"rbp","BP"},{"ebp","BP"},{"rip","PC"},
  {"r12","BASE"},{"r12d","BASE"},{"r13","R13"},{"r13d","R13"},
  {"r14","R14"},{"r14d","R14"},{"r15","R15"},{"r15d","R15"},
  {"r8","R8"},{"r8d","R8"},{"r8b","R8"},
  {"r9","R9"},{"r9d","R9"},{"r9b","R9"},
  {"r10","R10"},{"r10d","R10"},{"r10b","R10"},
  {"r11","R11"},{"r11d","R11"},{"r11b","R11"}
};
static const Pair mnems[] = {
  {"mov","COPY"},{"movq","COPY"},{"lea","ADDR"},
  {"addsd","FADD"},{"subsd","FSUB"},{"mulsd","FMUL"},{"divsd","FDIV"},
  {"add","IADD"},{"sub","ISUB"},{"imul","IMUL"},{"idiv","IDIV"},
  {"cmp","ICMP"},{"ucomisd","FCMP"},{"comisd","FCMP"},
  {"cvtsi2sd","I2F"},{"cvttsd2si","F2I"},{"movzx","ZEXT"},{"movsx","SEXT"}
};
static const char *lookup(const Pair *table, size_t count, const char *s, size_t n){
  for(size_t i=0;i<count;i++)
    if(strlen(table[i].from)==n && !memcmp(s,table[i].from,n)) return table[i].to;
  return NULL;
}
#define LOOKUP(t,s,n) lookup(t,sizeof(t)/sizeof(t[0]),s,n)
static int word(unsigned char c){ return isalnum(c) || c=='_'; }
static void operands(FILE *out, const char *s){
  while(*s){
    if(!word((unsigned char)*s)){ fputc(*s++,out); continue; }
    const char *start=s;
    while(word((unsigned char)*s)) s++;
    size_t n=(size_t)(s-start);
    const char *r=LOOKUP(regs,start,n);
    if(r) fputs(r,out);
    else {
      int xmm=n>3 && !memcmp(start,"xmm",3);
      for(size_t i=3;xmm && i<n;i++) if(!isdigit((unsigned char)start[i])) xmm=0;
      if(xmm){ fputc('F',out); fwrite(start+3,1,n-3,out); }
      else fwrite(start,1,n,out);
    }
  }
}
static char *trim(char *s){
  while(isspace((unsigned char)*s)) s++;
  size_t n=strlen(s);
  while(n && isspace((unsigned char)s[n-1])) s[--n]=0;
  return s;
}
static void translate(FILE *out, char *line, size_t *number){
  if(line[0]==';'){ fprintf(out,"; %s\n",trim(line+1)); return; }
  size_t len=strlen(line);
  int instruction=len>=8 && line[6]==' ' && line[7]==' ';
  for(size_t i=0;instruction && i<6;i++)
    if(!strchr("0123456789abcdef",line[i])) instruction=0;
  /* Empty instructions are malformed, not silently dropped (or a crash). */
  char *s=instruction?trim(line+8):line;
  if(!instruction || !*s){ fprintf(out,"; UNTRANSLATED: %s\n",line); return; }
  char *end=s;
  while(*end && !isspace((unsigned char)*end)) end++;
  size_t n=(size_t)(end-s);
  char *ops=trim(end);
  fprintf(out,"I%-5zu ",(*number)++);
  const char *m=LOOKUP(mnems,s,n);
  if(m) fputs(m,out);
  else for(size_t i=0;i<n;i++) fputc(toupper((unsigned char)s[i]),out);
  if(*ops){
    fputc(' ',out);
    /* Named calls are opaque: a function named rax must stay named rax. */
    if(n==4 && !memcmp(s,"call",4)) fputs(ops,out);
    else operands(out,ops);
  }
  fputc('\n',out);
}
int main(int argc, char **argv){
  if(argc!=3){ fputs("usage: emit_to_ir <emit.log> <out.ir>\n",stderr); return 2; }
  if(!strcmp(argv[1],argv[2])){ fputs("emit_to_ir: input and output must differ\n",stderr); return 2; }
  FILE *in=fopen(argv[1],"rb");
  if(!in){ perror(argv[1]); return 1; }
  FILE *out=fopen(argv[2],"wb");
  if(!out){ perror(argv[2]); fclose(in); return 1; }
  fputs("; portable IR listing (docs/NATIVE_IR.md) -- translated from an\n"
        "; SX_EMIT_LOG instruction list by tools/emit_to_ir.c. This is an\n"
        "; analysis format: no backend assembles or executes it.\n",out);
  size_t cap=256, len=0, number=0;
  char *line=malloc(cap);
  int c, failed=!line;
  while(!failed && (c=fgetc(in))!=EOF){
    if(c==0){ fputs("emit_to_ir: NUL byte in text log\n",stderr); failed=1; break; }
    if(c=='\n'){ line[len]=0; translate(out,line,&number); len=0; continue; }
    if(len+1>=cap){
      if(cap>SIZE_MAX/2){ failed=1; break; }
      char *next=realloc(line,cap*2);
      if(!next){ failed=1; break; }
      line=next; cap*=2;
    }
    line[len++]=(char)c;
  }
  if(!failed && len){ line[len]=0; translate(out,line,&number); }
  failed=failed || ferror(in) || ferror(out);
  free(line);
  if(fclose(in)) failed=1;
  if(fclose(out)) failed=1;
  if(failed){ fputs("emit_to_ir: translation failed (invalid input, allocation or I/O error)\n",stderr); return 1; }
  return 0;
}
