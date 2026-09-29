/* sxc_seed_min.c — pure-min → C seed capable of compiling compiler_min.sa
 * Smaller alternative to sxc_seed.c (~11KB vs ~44KB).
 * Usage: sxc_seed_min in.sa > out.c
 */
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *S; static size_t N, P;
enum { TY_NUM=0, TY_STR=1 };
static char *vn[512]; static int vt[512]; static int nv;

static void die(const char *m){ fprintf(stderr,"seed_min: %s at %zu\n", m, P); exit(1); }
static void skip(void){
  for(;;){
    while(P<N && isspace((unsigned char)S[P])) P++;
    if(P+1<N && S[P]=='/' && S[P+1]=='/'){ while(P<N && S[P]!='\n') P++; continue; }
    break;
  }
}
static int at(const char *k){
  size_t n=strlen(k); if(P+n>N) return 0;
  if(memcmp(S+P,k,n)) return 0;
  if(isalpha((unsigned char)k[0])||k[0]=='_'){
    char c=S[P+n]; if(isalnum((unsigned char)c)||c=='_') return 0;
  }
  return 1;
}
static void eat(const char *k){ skip(); if(!at(k)) die(k); P+=strlen(k); }
static int isid0(char c){ return isalpha((unsigned char)c)||c=='_'; }
static int isid(char c){ return isalnum((unsigned char)c)||c=='_'; }
static char *parse_id(void){
  skip(); if(P>=N||!isid0(S[P])) die("id");
  size_t a=P; while(P<N&&isid(S[P])) P++;
  size_t n=P-a; char *s=malloc(n+1); memcpy(s,S+a,n); s[n]=0; return s;
}
static int findv(const char *n){ for(int i=0;i<nv;i++) if(!strcmp(vn[i],n)) return i; return -1; }
static void setv(const char *n, int ty){
  int i=findv(n);
  if(i<0){ if(nv>=512) die("too many vars"); vn[nv]=strdup(n); vt[nv]=ty; nv++; }
  else vt[i]=ty;
}
static int getty(const char *n){ int i=findv(n); return i<0?TY_NUM:vt[i]; }

static char *expr(int *oty);

static char *primary(int *oty){
  skip();
  if(P<N && S[P]=='('){ P++; char *e=expr(oty); skip(); if(P>=N||S[P]!=')') die(")"); P++; return e; }
  if(P<N && S[P]=='"'){
    P++; size_t a=P; while(P<N && S[P]!='"'){ if(S[P]=='\\' && P+1<N) P+=2; else P++; }
    size_t n=P-a; if(P<N && S[P]=='"') P++;
    char *r=malloc(n+3); r[0]='"'; memcpy(r+1,S+a,n); r[1+n]='"'; r[2+n]=0; *oty=TY_STR; return r;
  }
  if(P<N && isdigit((unsigned char)S[P])){
    size_t a=P; while(P<N && isdigit((unsigned char)S[P])) P++;
    size_t n=P-a; char *r=malloc(n+1); memcpy(r,S+a,n); r[n]=0; *oty=TY_NUM; return r;
  }
  if(P<N && isid0(S[P])){
    char *id=parse_id(); skip();
    if(P<N && S[P]=='('){
      P++; char *args[16]; int aty[16]; int na=0; skip();
      if(P>=N||S[P]!=')'){
        for(;;){ args[na]=expr(&aty[na]); na++; skip(); if(P<N&&S[P]==','){P++;skip();continue;} break; }
      }
      if(P>=N||S[P]!=')') die(")"); P++;
      char buf[65536];
      if(!strcmp(id,"concat")&&na==2){
        snprintf(buf,sizeof buf,"sx_cat(%s,%s)",args[0],args[1]); *oty=TY_STR;
      } else if((!strcmp(id,"len")||!strcmp(id,"sx_len"))&&na==1){
        snprintf(buf,sizeof buf,"sx_len(%s)",args[0]); *oty=TY_NUM;
      } else if((!strcmp(id,"chr")||!strcmp(id,"sx_chr"))&&na==1){
        snprintf(buf,sizeof buf,"sx_chr(%s)",args[0]); *oty=TY_STR;
      } else if((!strcmp(id,"sx_index")||!strcmp(id,"sx_idx")||!strcmp(id,"index"))&&na==2){
        snprintf(buf,sizeof buf,"sx_idx(%s,%s)",args[0],args[1]); *oty=TY_NUM;
      } else if((!strcmp(id,"string_eq")||!strcmp(id,"sx_eq"))&&na==2){
        snprintf(buf,sizeof buf,"sx_eq(%s,%s)",args[0],args[1]); *oty=TY_NUM;
      } else if((!strcmp(id,"arg")||!strcmp(id,"sx_arg"))&&na==1){
        snprintf(buf,sizeof buf,"sx_arg((int)(%s))",args[0]); *oty=TY_STR;
      } else if((!strcmp(id,"arg_count")||!strcmp(id,"sx_argc"))&&na==0){
        snprintf(buf,sizeof buf,"sx_argc()"); *oty=TY_NUM;
      } else if((!strcmp(id,"read_file")||!strcmp(id,"sx_read"))&&na==1){
        snprintf(buf,sizeof buf,"sx_read(%s)",args[0]); *oty=TY_STR;
      } else if((!strcmp(id,"write_file")||!strcmp(id,"sx_write"))&&na==2){
        snprintf(buf,sizeof buf,"sx_write(%s,%s)",args[0],args[1]); *oty=TY_NUM;
      } else {
        size_t o=0; o+=snprintf(buf+o,sizeof buf-o,"%s(",id);
        for(int i=0;i<na;i++) o+=snprintf(buf+o,sizeof buf-o,"%s%s",i?",":"",args[i]);
        snprintf(buf+o,sizeof buf-o,")"); *oty=TY_NUM;
      }
      for(int i=0;i<na;i++) free(args[i]); free(id);
      return strdup(buf);
    }
    *oty=getty(id); char *r=strdup(id); free(id); return r;
  }
  die("primary"); return NULL;
}
static char *unary(int *oty){
  skip(); if(P<N && S[P]=='-'){ P++; char *e=unary(oty); char *r=malloc(strlen(e)+8); sprintf(r,"-(%s)",e); free(e); *oty=TY_NUM; return r; }
  return primary(oty);
}
static char *mul(int *oty){
  char *l=unary(oty);
  for(;;){ skip(); if(P>=N||(S[P]!='*'&&S[P]!='/')) break; char op=S[P++]; int rt; char *r=unary(&rt);
    char *t=malloc(strlen(l)+strlen(r)+8); sprintf(t,"(%s%c%s)",l,op,r); free(l); free(r); l=t; *oty=TY_NUM; }
  return l;
}
static char *add(int *oty){
  char *l=mul(oty);
  for(;;){ skip(); if(P>=N||(S[P]!='+'&&S[P]!='-')) break; char op=S[P++]; int rt; char *r=mul(&rt);
    if(op=='+' && (*oty==TY_STR||rt==TY_STR)){
      char *t=malloc(strlen(l)+strlen(r)+24); sprintf(t,"sx_cat(%s,%s)",l,r); free(l); free(r); l=t; *oty=TY_STR;
    } else {
      char *t=malloc(strlen(l)+strlen(r)+8); sprintf(t,"(%s%c%s)",l,op,r); free(l); free(r); l=t; *oty=TY_NUM;
    }
  }
  return l;
}
static char *cmp(int *oty){
  char *l=add(oty); skip();
  if(P+1<N && S[P]=='='&&S[P+1]=='='){ P+=2; int rt; char *r=add(&rt); char *t=malloc(strlen(l)+strlen(r)+24); sprintf(t,"((%s)==(%s))",l,r); free(l); free(r); *oty=TY_NUM; return t; }
  if(P+1<N && S[P]=='!'&&S[P+1]=='='){ P+=2; int rt; char *r=add(&rt); char *t=malloc(strlen(l)+strlen(r)+24); sprintf(t,"((%s)!=(%s))",l,r); free(l); free(r); *oty=TY_NUM; return t; }
  if(P+1<N && S[P]=='<'&&S[P+1]=='='){ P+=2; int rt; char *r=add(&rt); char *t=malloc(strlen(l)+strlen(r)+24); sprintf(t,"((%s)<=(%s))",l,r); free(l); free(r); *oty=TY_NUM; return t; }
  if(P+1<N && S[P]=='>'&&S[P+1]=='='){ P+=2; int rt; char *r=add(&rt); char *t=malloc(strlen(l)+strlen(r)+24); sprintf(t,"((%s)>=(%s))",l,r); free(l); free(r); *oty=TY_NUM; return t; }
  if(P<N && S[P]=='<'){ P++; int rt; char *r=add(&rt); char *t=malloc(strlen(l)+strlen(r)+24); sprintf(t,"((%s)<(%s))",l,r); free(l); free(r); *oty=TY_NUM; return t; }
  if(P<N && S[P]=='>'){ P++; int rt; char *r=add(&rt); char *t=malloc(strlen(l)+strlen(r)+24); sprintf(t,"((%s)>(%s))",l,r); free(l); free(r); *oty=TY_NUM; return t; }
  return l;
}
static char *andexpr(int *oty){
  char *l=cmp(oty);
  for(;;){ skip(); if(!(P+1<N && S[P]=='&'&&S[P+1]=='&')) break; P+=2; int rt; char *r=cmp(&rt);
    char *t=malloc(strlen(l)+strlen(r)+24); sprintf(t,"((%s)&&(%s))",l,r); free(l); free(r); l=t; *oty=TY_NUM; }
  return l;
}
static char *expr(int *oty){
  char *l=andexpr(oty);
  for(;;){ skip(); if(!(P+1<N && S[P]=='|'&&S[P+1]=='|')) break; P+=2; int rt; char *r=andexpr(&rt);
    char *t=malloc(strlen(l)+strlen(r)+24); sprintf(t,"((%s)||(%s))",l,r); free(l); free(r); l=t; *oty=TY_NUM; }
  return l;
}

static void stmt(void);
static void block(void){
  skip(); eat("{");
  for(;;){ skip(); if(P>=N) die("}"); if(S[P]=='}'){ P++; return; } stmt(); }
}

static void stmt(void){
  skip(); if(P>=N||S[P]=='}') return;
  if(at("hold")){
    P+=4; char *n=parse_id(); skip(); eat("="); int ty; char *e=expr(&ty); setv(n,ty);
    printf("  %s = %s;\n", n, e);
    free(n); free(e); return;
  }
  if(at("show")){
    P+=4; skip(); int ty; char *e=expr(&ty);
    if(ty==TY_STR) printf("  puts(%s);\n", e);
    else printf("  printf(\"%%g\\n\", (double)(%s));\n", e);
    free(e); return;
  }
  if(at("when")){
    P+=4; int ty; char *c=expr(&ty); printf("  if(%s) {\n", c); free(c); block();
    skip(); if(at("otherwise")){ P+=9; printf("  } else {\n"); block(); }
    printf("  }\n"); return;
  }
  if(at("while")){
    P+=5; int ty; char *c=expr(&ty); printf("  while(%s) {\n", c); free(c); block(); printf("  }\n"); return;
  }
  die("stmt");
}

static void preamble(void){
  puts("#include <stdio.h>");
  puts("#include <stdlib.h>");
  puts("#include <string.h>");
  puts("static char *sx_cat(const char *a,const char *b){ if(!a)a=\"\"; if(!b)b=\"\"; size_t la=strlen(a),lb=strlen(b); char *r=malloc(la+lb+1); memcpy(r,a,la); memcpy(r+la,b,lb); r[la+lb]=0; return r; }");
  puts("static double sx_len(const char *s){ return (double)strlen(s?s:\"\"); }");
  puts("static char *sx_chr(double v){ char *r=malloc(2); r[0]=(char)(long)v; r[1]=0; return r; }");
  puts("static double sx_eq(const char *a,const char *b){ return strcmp(a?a:\"\",b?b:\"\")==0?1.0:0.0; }");
  puts("static double sx_idx(const char *s,double v){ long i=(long)v; long L=(long)strlen(s?s:\"\"); if(i<0)i+=L; if(i<0||i>=L){fputs(\"sx: index\\n\",stderr);exit(1);} return (double)(unsigned char)s[i]; }");
  puts("static int g_argc; static char **g_argv;");
  puts("static double sx_argc(void){ return (double)g_argc; }");
  puts("static char *sx_arg(int i){ return (i>=0&&i<g_argc)?g_argv[i]:\"\"; }");
  puts("static char *sx_read(const char *p){ FILE *f=fopen(p,\"rb\"); if(!f) return strdup(\"\"); fseek(f,0,SEEK_END); long n=ftell(f); fseek(f,0,SEEK_SET); char *b=malloc((size_t)n+1); size_t rd=fread(b,1,(size_t)n,f); b[rd]=0; fclose(f); return b; }");
  puts("static double sx_write(const char *p,const char *s){ FILE *f=fopen(p,\"wb\"); if(!f) return 0; fputs(s?s:\"\",f); fclose(f); return 1; }");
  puts("int main(int argc,char **argv){ g_argc=argc; g_argv=argv;");
}

static void collect(void){
  size_t save=P; nv=0;
  while(P<N){
    skip(); if(P>=N) break;
    if(at("hold")){
      P+=4; char *id=parse_id(); skip(); if(at("=")){ P++; skip();
        int ty=TY_NUM;
        if(P<N && S[P]=='"') ty=TY_STR;
        else if(at("concat")||at("chr")||at("read_file")||at("arg")||at("sx_cat")||at("sx_chr")||at("sx_read")||at("sx_arg")) ty=TY_STR;
        else if(P<N && isid0(S[P])){ char *t=parse_id(); int i=findv(t); if(i>=0&&vt[i]==TY_STR) ty=TY_STR; free(t); }
        setv(id,ty);
      }
      free(id);
      continue;
    }
    if(S[P]=='"'){ P++; while(P<N&&S[P]!='"'){ if(S[P]=='\\'&&P+1<N)P+=2; else P++; } if(P<N)P++; continue; }
    P++;
  }
  P=save;
}

static void decls(void){
  for(int i=0;i<nv;i++){
    if(vt[i]==TY_STR) printf("  char *%s = \"\";\n", vn[i]);
    else printf("  double %s = 0;\n", vn[i]);
  }
}

int main(int argc, char **argv){
  if(argc<2){ fprintf(stderr,"Usage: sxc_seed_min <in.sa>\n"); return 1; }
  FILE *f=fopen(argv[1],"rb"); if(!f) die("open");
  fseek(f,0,SEEK_END); long n=ftell(f); fseek(f,0,SEEK_SET);
  S=malloc((size_t)n+1); N=(size_t)fread(S,1,(size_t)n,f); S[N]=0; fclose(f); P=0;
  for(int pass=0;pass<4;pass++) collect();
  P=0;
  preamble(); decls();
  while(P<N){ skip(); if(P>=N) break; stmt(); }
  puts("  return 0;\n}");
  return 0;
}
