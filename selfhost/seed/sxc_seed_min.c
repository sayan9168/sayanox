/* sxc_seed_min.c — minimal pure-min → C seed (smaller bootstrap).
 * Dialect: hold / show / when / while, nums, strings, + - * /, == != < > <= >=,
 *          concat/len/chr/arg/arg_count/read_file/write_file/string_eq as calls.
 * Emits standalone C (no sx_runtime.h). Not a full compiler_min host.
 * Usage: sxc_seed_min in.sa > out.c
 */
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *src; static size_t len; static size_t pos;
static char *names[256]; static int nnames;

static void die(const char *m){ fprintf(stderr,"seed_min: %s\n",m); exit(1); }
static void skip(void){
  for(;;){
    while(pos<len && isspace((unsigned char)src[pos])) pos++;
    if(pos+1<len && src[pos]=='/' && src[pos+1]=='/'){ while(pos<len && src[pos]!='\n') pos++; continue; }
    break;
  }
}
static int at(const char *k){ size_t n=strlen(k); if(pos+n>len) return 0;
  if(strncmp(src+pos,k,n)) return 0;
  if(isalpha((unsigned char)k[0])||k[0]=='_'){ char c=src[pos+n]; if(isalnum((unsigned char)c)||c=='_') return 0; }
  return 1; }
static void eat(const char *k){ skip(); if(!at(k)) die(k); pos+=strlen(k); }
static int isid0(char c){ return isalpha((unsigned char)c)||c=='_'; }
static int isid(char c){ return isalnum((unsigned char)c)||c=='_'; }
static char *parse_id(void){ skip(); if(!isid0(src[pos])) die("id"); size_t a=pos; while(pos<len&&isid(src[pos])) pos++;
  size_t n=pos-a; char *s=malloc(n+1); memcpy(s,src+a,n); s[n]=0; return s; }
static void decl(const char *n){ for(int i=0;i<nnames;i++) if(!strcmp(names[i],n)) return;
  if(nnames>=256) die("too many vars"); names[nnames++]=strdup(n); }

static void expr(char *buf, size_t cap);
static void primary(char *buf, size_t cap){
  skip();
  if(src[pos]=='('){ pos++; expr(buf,cap); skip(); if(src[pos]!=')') die(")"); pos++; return; }
  if(src[pos]=='"'){ pos++; size_t a=pos; while(pos<len&&src[pos]!='"'){ if(src[pos]=='\\'&&pos+1<len) pos+=2; else pos++; }
    size_t n=pos-a; if(src[pos]=='"') pos++;
    if(n+3>=cap) die("str"); buf[0]='"'; memcpy(buf+1,src+a,n); buf[1+n]='"'; buf[2+n]=0; return; }
  if(isdigit((unsigned char)src[pos])){ size_t a=pos; while(pos<len&&isdigit((unsigned char)src[pos])) pos++;
    size_t n=pos-a; if(n>=cap) die("num"); memcpy(buf,src+a,n); buf[n]=0; return; }
  if(isid0(src[pos])){
    char *id=parse_id(); skip();
    if(src[pos]=='('){
      pos++; char args[8][256]; int na=0; skip();
      if(src[pos]!=')'){ for(;;){ expr(args[na],256); na++; skip(); if(src[pos]==','){pos++;skip();continue;} break; } }
      if(src[pos]!=')') die(")"); pos++;
      if(!strcmp(id,"concat")&&na==2) snprintf(buf,cap,"sx_cat(%s,%s)",args[0],args[1]);
      else if(!strcmp(id,"len")&&na==1) snprintf(buf,cap,"sx_len(%s)",args[0]);
      else if(!strcmp(id,"chr")&&na==1) snprintf(buf,cap,"sx_chr(%s)",args[0]);
      else if(!strcmp(id,"string_eq")&&na==2) snprintf(buf,cap,"sx_eq(%s,%s)",args[0],args[1]);
      else if(!strcmp(id,"arg")&&na==1) snprintf(buf,cap,"sx_arg((int)(%s))",args[0]);
      else if(!strcmp(id,"arg_count")&&na==0) snprintf(buf,cap,"sx_argc()");
      else if(!strcmp(id,"read_file")&&na==1) snprintf(buf,cap,"sx_read(%s)",args[0]);
      else if(!strcmp(id,"write_file")&&na==2) snprintf(buf,cap,"sx_write(%s,%s)",args[0],args[1]);
      else { size_t o=0; o+=snprintf(buf+o,cap-o,"%s(",id);
        for(int i=0;i<na;i++) o+=snprintf(buf+o,cap-o,"%s%s",i?",":"",args[i]);
        snprintf(buf+o,cap-o,")"); }
      free(id); return;
    }
    decl(id); snprintf(buf,cap,"%s",id); free(id); return;
  }
  die("primary");
}
static void unary(char *buf, size_t cap){ skip(); if(src[pos]=='-'){ pos++; char t[512]; unary(t,sizeof t); snprintf(buf,cap,"-(%s)",t); return; } primary(buf,cap); }
static void mul(char *buf, size_t cap){ unary(buf,cap); for(;;){ skip(); char op=src[pos]; if(op!='*'&&op!='/') break; pos++; char r[512]; unary(r,sizeof r);
  char t[1024]; snprintf(t,sizeof t,"(%s%c%s)",buf,op,r); snprintf(buf,cap,"%s",t); } }
static void add(char *buf, size_t cap){ mul(buf,cap); for(;;){ skip(); char op=src[pos]; if(op!='+'&&op!='-') break; pos++; char r[512]; mul(r,sizeof r);
  char t[1024]; snprintf(t,sizeof t,"(%s%c%s)",buf,op,r); snprintf(buf,cap,"%s",t); } }
static void expr(char *buf, size_t cap){
  add(buf,cap); skip();
  if(pos+1<len && src[pos]=='='&&src[pos+1]=='='){ pos+=2; char r[512]; add(r,sizeof r); char t[1024]; snprintf(t,sizeof t,"((%s)==(%s))",buf,r); snprintf(buf,cap,"%s",t); return; }
  if(pos+1<len && src[pos]=='!'&&src[pos+1]=='='){ pos+=2; char r[512]; add(r,sizeof r); char t[1024]; snprintf(t,sizeof t,"((%s)!=(%s))",buf,r); snprintf(buf,cap,"%s",t); return; }
  if(pos+1<len && src[pos]=='<'&&src[pos+1]=='='){ pos+=2; char r[512]; add(r,sizeof r); char t[1024]; snprintf(t,sizeof t,"((%s)<=(%s))",buf,r); snprintf(buf,cap,"%s",t); return; }
  if(pos+1<len && src[pos]=='>'&&src[pos+1]=='='){ pos+=2; char r[512]; add(r,sizeof r); char t[1024]; snprintf(t,sizeof t,"((%s)>=(%s))",buf,r); snprintf(buf,cap,"%s",t); return; }
  if(src[pos]=='<'){ pos++; char r[512]; add(r,sizeof r); char t[1024]; snprintf(t,sizeof t,"((%s)<(%s))",buf,r); snprintf(buf,cap,"%s",t); return; }
  if(src[pos]=='>'){ pos++; char r[512]; add(r,sizeof r); char t[1024]; snprintf(t,sizeof t,"((%s)>(%s))",buf,r); snprintf(buf,cap,"%s",t); return; }
}

static void stmt(void);
static void block(void){ skip(); eat("{"); while(pos<len){ skip(); if(src[pos]=='}'){ pos++; return; } stmt(); } die("}"); }

static void stmt(void){
  skip(); if(pos>=len||src[pos]=='}') return;
  if(at("hold")){ pos+=4; char *n=parse_id(); decl(n); skip(); eat("="); char e[1024]; expr(e,sizeof e); printf("  %s = %s;\n",n,e); free(n); return; }
  if(at("show")){ pos+=4; skip(); if(src[pos]=='"'){ char e[1024]; primary(e,sizeof e); printf("  puts(%s);\n",e); return; }
    char e[1024]; expr(e,sizeof e); printf("  printf(\"%%g\\n\", (double)(%s));\n",e); return; }
  if(at("when")){ pos+=4; char c[1024]; expr(c,sizeof c); printf("  if(%s) {\n",c); block();
    skip(); if(at("otherwise")){ pos+=9; printf("  } else {\n"); block(); } printf("  }\n"); return; }
  if(at("while")){ pos+=5; char c[1024]; expr(c,sizeof c); printf("  while(%s) {\n",c); block(); printf("  }\n"); return; }
  die("stmt");
}

static void emit_preamble(void){
  puts("#include <stdio.h>");
  puts("#include <stdlib.h>");
  puts("#include <string.h>");
  puts("static char *sx_cat(const char *a,const char *b){ size_t la=strlen(a),lb=strlen(b); char *r=malloc(la+lb+1); memcpy(r,a,la); memcpy(r+la,b,lb); r[la+lb]=0; return r; }");
  puts("static double sx_len(const char *s){ return (double)strlen(s); }");
  puts("static char *sx_chr(double v){ char *r=malloc(2); r[0]=(char)(long)v; r[1]=0; return r; }");
  puts("static int sx_eq(const char *a,const char *b){ return !strcmp(a,b); }");
  puts("static int g_argc; static char **g_argv;");
  puts("static double sx_argc(void){ return (double)g_argc; }");
  puts("static char *sx_arg(int i){ return (i>=0&&i<g_argc)?g_argv[i]:\"\"; }");
  puts("static char *sx_read(const char *p){ FILE *f=fopen(p,\"rb\"); if(!f) return strdup(\"\"); fseek(f,0,SEEK_END); long n=ftell(f); fseek(f,0,SEEK_SET); char *b=malloc((size_t)n+1); fread(b,1,(size_t)n,f); b[n]=0; fclose(f); return b; }");
  puts("static double sx_write(const char *p,const char *s){ FILE *f=fopen(p,\"wb\"); if(!f) return 0; fputs(s,f); fclose(f); return 1; }");
  puts("int main(int argc,char **argv){ g_argc=argc; g_argv=argv;");
}
static void emit_decls(void){
  for(int i=0;i<nnames;i++) printf("  double %s = 0;\n", names[i]);
}

int main(int argc,char **argv){
  if(argc<2){ fprintf(stderr,"Usage: sxc_seed_min <in.sa>\n"); return 1; }
  FILE *f=fopen(argv[1],"rb"); if(!f) die("open");
  fseek(f,0,SEEK_END); long n=ftell(f); fseek(f,0,SEEK_SET);
  src=malloc((size_t)n+1); len=(size_t)fread(src,1,(size_t)n,f); src[len]=0; fclose(f); pos=0;
  size_t save=pos; nnames=0;
  while(pos<len){ skip(); if(pos>=len) break;
    if(at("hold")){ pos+=4; char *id=parse_id(); decl(id); free(id); while(pos<len&&src[pos]!='\n') pos++; continue; }
    if(at("when")||at("while")||at("show")||at("otherwise")){ while(pos<len&&src[pos]!='\n'&&src[pos]!='{') pos++; if(src[pos]=='{') pos++; continue; }
    pos++;
  }
  pos=save;
  emit_preamble();
  emit_decls();
  while(pos<len){ skip(); if(pos>=len) break; stmt(); }
  puts("  return 0;\n}");
  return 0;
}
