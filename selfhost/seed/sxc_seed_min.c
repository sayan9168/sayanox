/* sxc_seed_min.c — pure-min + make/give + lists + structs + use (modules)
 * Usage: sxc_seed_min in.sa > out.c
 *
 * `use "file.sa"` statements are expanded before parsing: the file text is
 * spliced in place, up to depth 8.  Only a use that starts a statement is
 * expanded; strings and // comments are copied verbatim.  A missing file is
 * a hard error (never silent).
 */
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *USEDIR = "";   /* directory of the main input file */

static char *read_all(const char *p){
  FILE *f=fopen(p,"rb"); if(!f) return NULL;
  fseek(f,0,SEEK_END); long n=ftell(f); fseek(f,0,SEEK_SET);
  if(n<0) n=0;
  char *b=malloc((size_t)n+1); if(!b) exit(1);
  size_t rd=fread(b,1,(size_t)n,f); b[rd]=0; fclose(f); return b;
}

/* expand use "path" statements; depth counts nested includes (max 8) */
static char *expand_use(const char *src, int depth){
  size_t n=strlen(src), i=0, o=0, cap=n+64;
  char *out=malloc(cap); if(!out) exit(1);
  int st=1;                                  /* at a statement start? */
  while(i<n){
    char c=src[i];
    if(c=='"'){                              /* string literal: copy verbatim */
      if(o+2>cap){ cap=cap*2+64; out=realloc(out,cap); }
      out[o++]=src[i++];
      while(i<n){
        char d=src[i++];
        if(o+3>cap){ cap=cap*2+64; out=realloc(out,cap); }
        out[o++]=d;
        if(d=='\\'&&i<n) out[o++]=src[i++];
        else if(d=='"') break;
      }
      st=0; continue;
    }
    if(c=='/'&&i+1<n&&src[i+1]=='/'){        /* comment: copy to end of line */
      while(i<n && src[i]!='\n'){
        if(o+2>cap){ cap=cap*2+64; out=realloc(out,cap); }
        out[o++]=src[i++];
      }
      continue;
    }
    if(st && strncmp(src+i,"use",3)==0 &&
       !(isalnum((unsigned char)src[i+3])||src[i+3]=='_')){
      size_t j=i+3;
      while(j<n && (src[j]==' '||src[j]=='\t'||src[j]=='\r')) j++;
      if(j<n && src[j]=='"'){
        j++; size_t a=j; while(j<n && src[j]!='"') j++;
        char *path=malloc(j-a+1); memcpy(path,src+a,j-a); path[j-a]=0;
        if(depth>=8){ fprintf(stderr,"seed_min: use nesting deeper than 8: %s\n",path); exit(1); }
        char *sub=read_all(path);
        if(!sub && USEDIR[0]){
          char *full=malloc(strlen(USEDIR)+strlen(path)+1);
          strcpy(full,USEDIR); strcat(full,path); sub=read_all(full); free(full);
        }
        if(!sub){ fprintf(stderr,"seed_min: cannot open use file: %s\n",path); exit(1); }
        char *ex=expand_use(sub,depth+1);
        size_t el=strlen(ex);
        if(o+el+1>cap){ cap=(o+el+1)*2; out=realloc(out,cap); }
        memcpy(out+o,ex,el); o+=el;
        free(ex); free(sub); free(path);
        if(j<n) j++;                          /* closing quote */
        i=j; st=1; continue;
      }
    }
    if(o+2>cap){ cap=cap*2+64; out=realloc(out,cap); }
    out[o++]=c; i++;
    if(c=='{'||c=='}'||c=='\n') st=1;
    else if(c==' '||c=='\t'||c=='\r'){ /* keep st */ }
    else st=0;
  }
  out[o]=0; return out;
}

static char *S; static size_t N, P;
enum { TY_NUM=0, TY_STR=1, TY_LIST=2, TY_STRUCT=3 };
static char *vn[512]; static int vt[512]; static int vs[512];
static int nv;
static int in_fn;
/* index of the struct the last atom() built (a struct literal); -1 otherwise.
 * Used to type a nested literal value while a struct literal is parsed. */
static int last_si = -1;

/* fty[f] is the C type of a field: 0 = double, 1 = char * (string).
 * fset[f] is 1 once a struct literal has fixed that field's type: the first
 * literal that mentions a field decides, later literals must agree (a
 * mismatch is a hard error, never a silently wrong typedef). */
typedef struct { char *name; char *fields[16]; int nf; int fty[16]; int fsi[16]; int fset[16]; } StructDef;
static StructDef SD[32]; static int nsd;

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
static int find_struct(const char *n){ for(int i=0;i<nsd;i++) if(!strcmp(SD[i].name,n)) return i; return -1; }
/* how a struct field's type is named in a diagnostic */
static const char *ftyname(int si, int f){
  if(SD[si].fty[f]==1) return "a string";
  if(SD[si].fty[f]==2) return "a struct";
  return "a number";
}
static void setv(const char *n, int ty){
  int i=findv(n);
  if(i<0){ if(nv>=512) die("too many vars"); vn[nv]=strdup(n); vt[nv]=ty; vs[nv]=-1; nv++; }
  else vt[i]=ty;
}
static void setv_struct(const char *n, int si){
  int i=findv(n);
  if(i<0){ if(nv>=512) die("too many vars"); vn[nv]=strdup(n); vt[nv]=TY_STRUCT; vs[nv]=si; nv++; }
  else { vt[i]=TY_STRUCT; vs[i]=si; }
}
static int getty(const char *n){ int i=findv(n); return i<0?TY_NUM:vt[i]; }
static int getsi(const char *n){ int i=findv(n); return i<0?-1:vs[i]; }

static char *expr(int *oty);
static void stmt(void);
static void block(void);
static int field_type(const char *base, const char *fld, int *osi);

static void parse_struct_def(void){
  eat("struct");
  char *name=parse_id();
  if(find_struct(name)>=0){ free(name); skip(); eat("{"); int d=1; P++;
    while(P<N&&d){ if(S[P]=='{')d++; else if(S[P]=='}')d--; P++; }
    return;
  }
  if(nsd>=32) die("too many structs");
  StructDef *D=&SD[nsd];
  D->name=name; D->nf=0;
  memset(D->fty,0,sizeof D->fty);
  for(int i=0;i<16;i++) D->fsi[i]=-1;
  memset(D->fset,0,sizeof D->fset);
  skip(); eat("{");
  for(;;){
    skip();
    if(P>=N) die("}");
    if(S[P]=='}'){ P++; break; }
    if(S[P]==','){ P++; continue; }
    if(!isid0(S[P])){ P++; continue; }
    if(D->nf>=16) die("too many fields");
    D->fields[D->nf++]=parse_id();
  }
  nsd++;
}

static char *atom(int *oty){
  skip(); last_si = -1;
  if(P<N && S[P]=='('){ P++; char *e=expr(oty); skip(); if(P>=N||S[P]!=')') die(")"); P++; return e; }
  if(P<N && S[P]=='['){
    P++; char *els[64]; int ne=0; skip();
    if(P>=N||S[P]!=']'){
      for(;;){
        int et; els[ne++]=expr(&et); if(ne>=64) die("list too big");
        if(et==TY_STRUCT) die("a list cannot hold a struct value");
        skip(); if(P<N&&S[P]==','){P++;skip();continue;} break;
      }
    }
    skip(); if(P>=N||S[P]!=']') die("]"); P++;
    size_t need=32; for(int i=0;i<ne;i++) need+=strlen(els[i])+16;
    char *buf=malloc(need+32);
    size_t o=0; o+=snprintf(buf+o,need,"sx_llit(%d",ne);
    for(int i=0;i<ne;i++) o+=snprintf(buf+o,need-o,",(double)(%s)",els[i]);
    snprintf(buf+o,need-o,")");
    for(int i=0;i<ne;i++) free(els[i]);
    *oty=TY_LIST; return buf;
  }
  if(P<N && S[P]=='"'){
    P++; size_t a=P; while(P<N && S[P]!='"'){ if(S[P]=='\\' && P+1<N) P+=2; else P++; }
    size_t n=P-a; if(P<N && S[P]=='"') P++;
    char *r=malloc(n+3); r[0]='"'; memcpy(r+1,S+a,n); r[1+n]='"'; r[2+n]=0; *oty=TY_STR; return r;
  }
  if(P<N && (S[P]=='-'||S[P]=='+') && P+1<N && isdigit((unsigned char)S[P+1])){
    size_t a=P; P++; while(P<N && isdigit((unsigned char)S[P])) P++;
    size_t n=P-a; char *r=malloc(n+1); memcpy(r,S+a,n); r[n]=0; *oty=TY_NUM; return r;
  }
  if(P<N && isdigit((unsigned char)S[P])){
    size_t a=P; while(P<N && isdigit((unsigned char)S[P])) P++;
    size_t n=P-a; char *r=malloc(n+1); memcpy(r,S+a,n); r[n]=0; *oty=TY_NUM; return r;
  }
  if(P<N && isid0(S[P])){
    char *id=parse_id(); skip();
    int si=find_struct(id);
    if(si>=0 && P<N && S[P]=='{'){
      P++; char *slot[16]; int nvv=0;
      for(int f=0;f<16;f++) slot[f]=0;
      skip();
      if(P>=N||S[P]!='}'){
        for(;;){
          int fidx=-1;                 /* -1: positional value */
          skip();
          if(P<N && isid0(S[P])){
            size_t save=P;
            char *maybe=parse_id(); skip();
            if(P<N && S[P]==':'){ P++;
              for(int f=0;f<SD[si].nf;f++) if(!strcmp(SD[si].fields[f],maybe)){ fidx=f; break; }
              if(fidx<0) die("unknown struct field in literal");
              free(maybe);
            }
            else { P=save; free(maybe); }
          }
          int fi=(fidx>=0)?fidx:nvv;
          if(fi<0 || fi>=SD[si].nf) die("struct literal has more values than the struct has fields");
          if(slot[fi]) die("struct literal gives the same field twice");
          int et; char *v=expr(&et);
          slot[fi]=v; nvv++;
          if(et==TY_STR || et==TY_NUM){
            int ft=(et==TY_STR)?1:0;
            if(SD[si].fset[fi] && SD[si].fty[fi]!=ft){
              char msg[256];
              snprintf(msg,sizeof msg,"struct %s field '%s' is %s here, %s in an earlier literal",
                       SD[si].name, SD[si].fields[fi], ft?"a string":"a number",
                       ftyname(si,fi));
              die(msg);
            }
            SD[si].fty[fi]=ft; SD[si].fset[fi]=1;
          } else if(et==TY_STRUCT){
            /* a nested struct literal: only the literal form is supported,
             * and the nested struct must be declared first so the emitted
             * C typedefs are in an order a C compiler accepts (1 level) */
            if(last_si<0)
              die("a struct field must be filled by a nested struct literal");
            if(last_si>=si){
              char msg[256];
              snprintf(msg,sizeof msg,"struct %s must be declared before %s to nest it",
                       SD[last_si].name, SD[si].name);
              die(msg);
            }
            if(SD[si].fset[fi] && (SD[si].fty[fi]!=2 || SD[si].fsi[fi]!=last_si)){
              char msg[256];
              snprintf(msg,sizeof msg,"struct %s field '%s' is a struct here, %s in an earlier literal",
                       SD[si].name, SD[si].fields[fi], ftyname(si,fi));
              die(msg);
            }
            SD[si].fty[fi]=2; SD[si].fsi[fi]=last_si; SD[si].fset[fi]=1;
          } else if(et==TY_LIST){
            die("a struct field cannot hold a list");
          }
          skip(); if(P<N&&S[P]==','){P++;continue;} break;
        }
      }
      skip(); if(P>=N||S[P]!='}') die("}"); P++;
      size_t need=128;
      for(int f=0;f<SD[si].nf;f++) need += (slot[f]?strlen(slot[f]):0) + 8;
      char *buf=malloc(need);
      size_t o=0; o+=snprintf(buf+o,need,"((%s){", SD[si].name);
      for(int f=0;f<SD[si].nf;f++){
        const char *val=slot[f];
        if(!val && SD[si].fset[f] && SD[si].fty[f]==2){
          char msg[256];
          snprintf(msg,sizeof msg,"struct %s field '%s' is a struct and must be filled in every literal",
                   SD[si].name, SD[si].fields[f]);
          die(msg);
        }
        if(!val) val = SD[si].fty[f] ? "\"\"" : "0";
        o+=snprintf(buf+o,need-o,"%s%s", f?",":"", val);
      }
      snprintf(buf+o,need-o,"})");
      for(int f=0;f<16;f++) free(slot[f]);
      free(id); *oty=TY_STRUCT; last_si=si; return buf;
    }
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
        if(aty[0]==TY_LIST){ snprintf(buf,sizeof buf,"sx_llen(%s)",args[0]); *oty=TY_NUM; }
        else { snprintf(buf,sizeof buf,"sx_len(%s)",args[0]); *oty=TY_NUM; }
      } else if((!strcmp(id,"chr")||!strcmp(id,"sx_chr"))&&na==1){
        snprintf(buf,sizeof buf,"sx_chr(%s)",args[0]); *oty=TY_STR;
      } else if((!strcmp(id,"sx_index")||!strcmp(id,"sx_idx")||!strcmp(id,"index"))&&na==2){
        if(aty[0]==TY_LIST) snprintf(buf,sizeof buf,"sx_lget(%s,%s)",args[0],args[1]);
        else snprintf(buf,sizeof buf,"sx_idx(%s,%s)",args[0],args[1]);
        *oty=TY_NUM;
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
      } else if(!strcmp(id,"push")&&na==2){
        snprintf(buf,sizeof buf,"sx_lpush(%s,(double)(%s))",args[0],args[1]); *oty=TY_LIST;
      } else {
        size_t o=0; o+=snprintf(buf+o,sizeof buf-o,"%s(",id);
        for(int i=0;i<na;i++) o+=snprintf(buf+o,sizeof buf-o,"%s%s",i?",":"",args[i]);
        snprintf(buf+o,sizeof buf-o,")"); *oty=TY_NUM;
      }
      for(int i=0;i<na;i++) free(args[i]);
      free(id); return strdup(buf);
    }
    *oty=getty(id); return id;
  }
  die("primary"); return 0;
}

static char *primary(int *oty){
  char *l=atom(oty);
  for(;;){
    skip();
    if(P<N && S[P]=='['){
      P++; int it; char *ix=expr(&it); skip();
      if(P>=N||S[P]!=']') die("]"); P++;
      char *t=malloc(strlen(l)+strlen(ix)+24);
      if(*oty==TY_LIST){ sprintf(t,"sx_lget(%s,%s)",l,ix); *oty=TY_NUM; }
      else if(*oty==TY_STR){ sprintf(t,"sx_idx(%s,%s)",l,ix); *oty=TY_NUM; }
      else die("index on non-list/str");
      free(l); free(ix); l=t;
    } else if(P<N && S[P]=='.'){
      P++; char *fld=parse_id();
      int fsi=-1;
      int ft=field_type(l,fld,&fsi);
      char *t=malloc(strlen(l)+strlen(fld)+4);
      sprintf(t,"%s.%s",l,fld);
      free(l); free(fld); l=t; *oty=ft;
    } else break;
  }
  return l;
}

static char *unary(int *oty){
  skip();
  if(P<N && S[P]=='-'){ P++; char *e=unary(oty); char *t=malloc(strlen(e)+4); sprintf(t,"(-%s)",e); free(e); *oty=TY_NUM; return t; }
  return primary(oty);
}

static char *mul(int *oty){
  char *l=unary(oty);
  for(;;){
    skip(); char op=0;
    if(P<N && (S[P]=='*'||S[P]=='/'||S[P]=='%')){ op=S[P]; P++; }
    else break;
    int rt; char *r=unary(&rt);
    if(op=='%'){
      /* modulo: (double)((long)(a)%(long)(b)) */
      char *t=malloc(strlen(l)+strlen(r)+32);
      sprintf(t,"(double)((long)(%s)%%(long)(%s))",l,r);
      free(l); free(r); l=t; *oty=TY_NUM;
    } else {
      char *t=malloc(strlen(l)+strlen(r)+8); sprintf(t,"(%s%c%s)",l,op,r); free(l); free(r); l=t; *oty=TY_NUM;
    }
  }
  return l;
}

static char *add(int *oty){
  char *l=mul(oty);
  for(;;){
    skip(); char op=0;
    if(P<N && (S[P]=='+'||S[P]=='-')){ op=S[P]; P++; }
    else break;
    int rt; char *r=mul(&rt);
    if(*oty==TY_STR||rt==TY_STR){
      char *t=malloc(strlen(l)+strlen(r)+24); sprintf(t,"sx_cat(%s,%s)",l,r); free(l); free(r); l=t; *oty=TY_STR;
    } else {
      char *t=malloc(strlen(l)+strlen(r)+8); sprintf(t,"(%s%c%s)",l,op,r); free(l); free(r); l=t; *oty=TY_NUM;
    }
  }
  return l;
}

static char *cmp_(int *oty){
  char *l=add(oty);
  skip();
  if(P+1<N && S[P]=='='&&S[P+1]=='='){ P+=2; int rt; char *r=add(&rt); char *t=malloc(strlen(l)+strlen(r)+24); sprintf(t,"((%s)==(%s))",l,r); free(l); free(r); *oty=TY_NUM; return t; }
  if(P+1<N && S[P]=='!'&&S[P+1]=='='){ P+=2; int rt; char *r=add(&rt); char *t=malloc(strlen(l)+strlen(r)+24); sprintf(t,"((%s)!=(%s))",l,r); free(l); free(r); *oty=TY_NUM; return t; }
  if(P+1<N && S[P]=='<'&&S[P+1]=='='){ P+=2; int rt; char *r=add(&rt); char *t=malloc(strlen(l)+strlen(r)+24); sprintf(t,"((%s)<=(%s))",l,r); free(l); free(r); *oty=TY_NUM; return t; }
  if(P+1<N && S[P]=='>'&&S[P+1]=='='){ P+=2; int rt; char *r=add(&rt); char *t=malloc(strlen(l)+strlen(r)+24); sprintf(t,"((%s)>=(%s))",l,r); free(l); free(r); *oty=TY_NUM; return t; }
  if(P<N && S[P]=='<'){ P++; int rt; char *r=add(&rt); char *t=malloc(strlen(l)+strlen(r)+24); sprintf(t,"((%s)<(%s))",l,r); free(l); free(r); *oty=TY_NUM; return t; }
  if(P<N && S[P]=='>'){ P++; int rt; char *r=add(&rt); char *t=malloc(strlen(l)+strlen(r)+24); sprintf(t,"((%s)>(%s))",l,r); free(l); free(r); *oty=TY_NUM; return t; }
  return l;
}

static char *and_(int *oty){
  char *l=cmp_(oty);
  for(;;){
    skip(); if(!(P+1<N && S[P]=='&'&&S[P+1]=='&')) break;
    P+=2; int rt; char *r=cmp_(&rt);
    char *t=malloc(strlen(l)+strlen(r)+24); sprintf(t,"((%s)&&(%s))",l,r); free(l); free(r); l=t; *oty=TY_NUM;
  }
  return l;
}

static char *expr(int *oty){
  char *l=and_(oty);
  for(;;){
    skip(); if(!(P+1<N && S[P]=='|'&&S[P+1]=='|')) break;
    P+=2; int rt; char *r=and_(&rt);
    char *t=malloc(strlen(l)+strlen(r)+24); sprintf(t,"((%s)||(%s))",l,r); free(l); free(r); l=t; *oty=TY_NUM;
  }
  return l;
}

static void block(void){
  skip(); eat("{");
  for(;;){ skip(); if(P>=N) die("}"); if(S[P]=='}'){ P++; return; } stmt(); }
}

static void skip_block(void){
  skip(); if(P>=N||S[P]!='{') die("{");
  int d=0;
  while(P<N){
    if(S[P]=='"'){ P++; while(P<N&&S[P]!='"'){ if(S[P]=='\\'&&P+1<N)P+=2; else P++; } if(P<N)P++; continue; }
    if(S[P]=='{'){ d++; P++; continue; }
    if(S[P]=='}'){ d--; P++; if(d==0) return; continue; }
    P++;
  }
  die("} skip");
}

static void stmt(void){
  skip(); if(P>=N||S[P]=='}') return;
  if(at("struct")){
    P+=6; free(parse_id()); skip_block();
    return;
  }
  if(at("make")){
    if(in_fn) die("nested make");
    P+=4; free(parse_id()); skip(); eat("(");
    for(;;){ skip(); if(P<N&&S[P]==')'){P++;break;} free(parse_id()); skip(); if(P<N&&S[P]==','){P++;continue;} }
    skip_block();
    return;
  }
  if(at("give")){
    P+=4; skip(); int ty; char *e=expr(&ty); printf("  return %s;\n", e); free(e); return;
  }
  if(at("hold")){
    P+=4; char *n=parse_id(); skip(); eat("="); int ty; char *e=expr(&ty);
    int i=findv(n);
    if(i<0){
      if(ty==TY_STRUCT){
        setv_struct(n, 0);
        const char *p=e;
        if(p[0]=='('&&p[1]=='('){
          p+=2; char tname[64]; int ti=0;
          while(*p && *p!='{' && *p!=')' && ti<63) tname[ti++]=*p++;
          tname[ti]=0;
          int si=find_struct(tname);
          if(si>=0) setv_struct(n, si);
        }
        int si=getsi(n);
        if(si>=0) printf("  %s %s = %s;\n", SD[si].name, n, e);
        else printf("  /* struct */ %s = %s;\n", n, e);
      } else {
        setv(n,ty);
        if(ty==TY_STR) printf("  char *%s = %s;\n", n, e);
        else if(ty==TY_LIST) printf("  sx_list *%s = %s;\n", n, e);
        else printf("  double %s = %s;\n", n, e);
      }
    } else {
      if(vt[i]==TY_STR){
        /* Universal safe string reassignment: evaluate RHS into a temp FIRST,
         * then free the old LHS value, then assign. This avoids use-after-free
         * when RHS reads the current LHS value (concat-into-self or aliased
         * variables). Wrap plain literals and bare variable names with
         * sx_sb_from so the LHS always owns a fresh builder; sx_cat/sx_chr/
         * sx_arg/sx_read/sx_trim already return fresh owning builders and
         * must NOT be re-wrapped (that would leak their result). */
        int need_copy = (e[0]=='"') || (strncmp(e,"sx_",3)!=0 && e[0]!='_');
        printf("  { char *_sx_v = %s%s%s; sx_sb_free(%s); %s = _sx_v; }\n",
               need_copy?"sx_sb_from(":"", e, need_copy?")":"", n, n);
      } else printf("  %s = %s;\n", n, e);
    }
    free(n); free(e); return;
  }
  if(at("show")){
    P+=4; skip(); int ty; char *e=expr(&ty);
    if(ty==TY_STR) printf("  puts(%s);\n", e);
    else if(ty==TY_LIST) printf("  printf(\"[list len=%%g]\\n\", sx_llen(%s));\n", e);
    else printf("  printf(\"%%g\\n\", (double)(%s));\n", e);
    free(e); return;
  }
  if(at("when")){
    P+=4; int ty; char *c=expr(&ty); printf("  if(%s) {\n", c); free(c); block();
    skip();
    if(at("otherwise")){ P+=9; printf("  } else {\n"); block(); }
    else if(at("else")){ P+=4; printf("  } else {\n"); block(); }
    printf("  }\n"); return;
  }
  if(at("while")){
    P+=5; int ty; char *c=expr(&ty); printf("  while(%s) {\n", c); free(c); block(); printf("  }\n"); return;
  }
  die("stmt");
}

static void emit_one_fn(void){
  eat("make"); char *name=parse_id(); skip(); eat("(");
  char *params[16]; int np=0; skip();
  if(P>=N||S[P]!=')'){
    for(;;){ params[np++]=parse_id(); skip(); if(P<N&&S[P]==','){P++;skip();continue;} break; }
  }
  eat(")");
  printf("static double %s(", name);
  for(int i=0;i<np;i++) printf("%sdouble %s", i?", ":"", params[i]);
  printf("){\n");
  int saved_nv=nv;
  for(int i=0;i<np;i++) setv(params[i], TY_NUM);
  in_fn=1; skip(); eat("{");
  for(;;){ skip(); if(P>=N) die("}"); if(S[P]=='}'){ P++; break; } stmt(); }
  in_fn=0;
  printf("  return 0;\n}\n\n");
  while(nv>saved_nv){ free(vn[nv-1]); nv--; }
  for(int i=0;i<np;i++) free(params[i]); free(name);
}

static void emit_all_fns(void){
  size_t save=P;
  while(P<N){
    skip(); if(P>=N) break;
    if(at("make")){ emit_one_fn(); continue; }
    if(at("struct")){ P+=6; free(parse_id()); skip_block(); continue; }
    if(S[P]=='"'){ P++; while(P<N&&S[P]!='"'){ if(S[P]=='\\'&&P+1<N)P+=2; else P++; } if(P<N)P++; continue; }
    P++;
  }
  P=save;
}

static void emit_typedefs(void){
  for(int i=0;i<nsd;i++){
    printf("typedef struct {");
    for(int f=0;f<SD[i].nf;f++){
      if(SD[i].fty[f]==2) printf(" %s %s;", SD[SD[i].fsi[f]].name, SD[i].fields[f]);
      else if(SD[i].fty[f]) printf(" char *%s;", SD[i].fields[f]);
      else printf(" double %s;", SD[i].fields[f]);
    }
    printf(" } %s;\n", SD[i].name);
  }
}

/* struct index of field `fld` in struct `si` when it is used as the base of a
 * further .field; a field that never got a nested struct literal has no struct
 * type and cannot be chained through, so that is a hard error */
static int nested_si(int si, const char *fld){
  for(int f=0;f<SD[si].nf;f++)
    if(!strcmp(SD[si].fields[f],fld)){
      if(SD[si].fty[f]==2) return SD[si].fsi[f];
      char msg[256];
      snprintf(msg,sizeof msg,
               "struct %s field '%s' has no struct type; fill it with a nested struct literal",
               SD[si].name, fld);
      die(msg);
    }
  return -1;   /* unknown field: keep the old "treat as a number" behaviour */
}

/* the struct a dotted expression like `l` or `l.a` names, -1 if it is not a
 * struct or the chain passes through a non-struct field */
static int resolve_base_si(const char *base){
  size_t bl=strlen(base), k=0;
  while(k<bl && isid(base[k])) k++;
  if(k==0 || k>=255) return -1;
  char sv[256]; memcpy(sv,base,k); sv[k]=0;
  int vi=findv(sv);
  if(vi<0 || vt[vi]!=TY_STRUCT || vs[vi]<0) return -1;
  int si=vs[vi];
  for(size_t j=k;j<bl;){
    if(base[j]!='.') return -1;
    size_t s2=j+1, e2=s2;
    while(e2<bl && isid(base[e2])) e2++;
    size_t fl=e2-s2;
    if(fl==0 || fl>=64) return -1;
    char fs[64]; memcpy(fs,base+s2,fl); fs[fl]=0;
    int ff=-1;
    for(int f=0;f<SD[si].nf;f++) if(!strcmp(SD[si].fields[f],fs)){ ff=f; break; }
    if(ff<0) return -1;
    si=nested_si(si,fs);               /* dies when the link is not a struct */
    if(si<0) return -1;
    j=e2;
  }
  return si;
}

/* type of field `fld` reached from the dotted expression `base` (which may
 * itself be a chain, e.g. `l.a`), with the nested struct index in *osi */
static int field_type(const char *base, const char *fld, int *osi){
  if(osi) *osi=-1;
  int si=resolve_base_si(base);
  if(si<0) return TY_NUM;
  for(int f=0;f<SD[si].nf;f++)
    if(!strcmp(SD[si].fields[f],fld)){
      if(SD[si].fty[f]==2){ if(osi) *osi=SD[si].fsi[f]; return TY_STRUCT; }
      return SD[si].fty[f] ? TY_STR : TY_NUM;
    }
  return TY_NUM;
}

static void preamble(void){
  puts("#include <stdio.h>"); puts("#include <stdlib.h>"); puts("#include <string.h>"); puts("#include <stdarg.h>"); puts("#include <stdint.h>"); puts("#include <stddef.h>");
  puts("typedef struct { double *d; long n; long cap; } sx_list;");
  puts("static sx_list *sx_llit(int n,...){ sx_list *L=malloc(sizeof*L); L->n=n; L->cap=n<4?4:n; L->d=malloc(sizeof(double)*(size_t)L->cap); va_list ap; va_start(ap,n); for(int i=0;i<n;i++) L->d[i]=va_arg(ap,double); va_end(ap); return L; }");
  puts("static double sx_lget(sx_list *L,double v){ long i=(long)v; if(!L){fputs(\"sx: null list\\n\",stderr);exit(1);} if(i<0)i+=L->n; if(i<0||i>=L->n){fputs(\"sx: list index\\n\",stderr);exit(1);} return L->d[i]; }");
  puts("static double sx_llen(sx_list *L){ return L?(double)L->n:0.0; }");
  puts("static sx_list *sx_lpush(sx_list *L,double v){ if(!L){L=malloc(sizeof*L); L->n=0; L->cap=4; L->d=malloc(sizeof(double)*4);} if(L->n>=L->cap){ L->cap*=2; L->d=realloc(L->d,sizeof(double)*(size_t)L->cap);} L->d[L->n++]=v; return L; }");
  puts("/* ----- amortised string builder -------------------------------------\n * Strings returned by sx_cat/sx_chr/sx_sb_from carry a hidden sx_sb header\n * with current length and capacity, so repeated concat() to the same LHS is\n * O(1) amortised instead of O(N^2). String literals, argv[] strings and\n * read_file() results do NOT have a header -- sx_cat detects that and copies\n * them into a fresh builder on first use. ---------------------------- */");
  puts("#include <stddef.h>");
  puts("typedef struct { size_t magic; size_t len; size_t cap; char data[1]; } sx_sb;");
  puts("#define SX_SB_MAGIC 0x53427566UL");
  puts("static sx_sb *sx_sb_hdr(const char *p){ return (sx_sb*)((char*)p - offsetof(sx_sb,data)); }");
  puts("static int sx_sb_is(const char *p){");
  puts("  if(!p) return 0;");
  puts("  if(((uintptr_t)p) & 7) return 0;");
  puts("  sx_sb *h=sx_sb_hdr(p);");
  puts("  if(h->magic!=SX_SB_MAGIC) return 0;");
  puts("  if(h->len > (1u<<28)) return 0;");
  puts("  if(h->cap < h->len || h->cap > (1u<<29)) return 0;");
  puts("  return 1;");
  puts("}");
  puts("static char *sx_sb_new(size_t cap){");
  puts("  if(cap<32) cap=32;");
  puts("  sx_sb *h=(sx_sb*)malloc(offsetof(sx_sb,data)+cap+1); if(!h){fputs(\"sx: out of memory\\n\",stderr);exit(1);}");
  puts("  h->magic=SX_SB_MAGIC; h->len=0; h->cap=cap; h->data[0]=0; return h->data; }");
  puts("static char *sx_sb_from(const char *s){ size_t n=strlen(s?s:\"\");");
  puts("  size_t cap=n<32?32:n; char *r=sx_sb_new(cap); if(n)memcpy(r,s,n); r[n]=0; sx_sb_hdr(r)->len=n; return r; }");
  puts("static void sx_sb_free(const char *p){ if(sx_sb_is(p)) free(sx_sb_hdr(p)); }");
  puts("static char *sx_sb_app(const char *a,const char *b){");
  puts("  const char *aa=a?a:\"\"; const char *bb=b?b:\"\";");
  puts("  int ia=sx_sb_is(aa);");
  puts("  size_t la=ia?sx_sb_hdr(aa)->len:strlen(aa);");
  puts("  size_t lb=strlen(bb);");
  puts("  /* snapshot b when b is a pointer INTO a's buffer (overlapping src/dst),");
  puts("   * so the memcpy below cannot clobber b before we read it. */");
  puts("  int overlap = (bb==aa) || (bb && bb>aa && bb<aa+la+1);");
  puts("  char btmp[512]; char *bdup=0; const char *bs=bb;");
  puts("  if(overlap){ if(lb+1<=sizeof(btmp)){memcpy(btmp,bb,lb);btmp[lb]=0;bs=btmp;} else{bdup=malloc(lb+1);memcpy(bdup,bb,lb);bdup[lb]=0;bs=bdup;} }");
  puts("  size_t need=la+lb;");
  puts("  /* IMPORTANT: sx_sb_app NEVER frees `a` or `b`. Old `a` is always freed");
  puts("   * by the assignment wrapper:  { char *_v = sx_cat(a,b); sx_sb_free(a); a=_v; }");
  puts("   * which evaluates RHS to a temp first, then frees the old LHS. This");
  puts("   * eliminates all double-free / use-after-free hazards from aliased vars");
  puts("   * (the LHS may currently point at another variable like `q`, and freeing");
  puts("   * it here would invalidate q for later use). Starting from a's existing");
  puts("   * cap when a is a builder keeps total allocations O(N log N) overall. */");
  puts("  size_t cap=ia?sx_sb_hdr(aa)->cap:32; while(cap<need+1)cap*=2;");
  puts("  char *r=sx_sb_new(cap); sx_sb *h=sx_sb_hdr(r);");
  puts("  if(la)memcpy(r,aa,la); memcpy(r+la,bs,lb); r[need]=0; h->len=need;");
  puts("  free(bdup);");
  puts("  return r;");
  puts("}");
  puts("static char *sx_cat(const char *a,const char *b){ return sx_sb_app((char*)a,b); }");
  puts("static double sx_len(const char *s){ return (double)strlen(s?s:\"\"); }");
  puts("static char *sx_chr(double v){ char *r=sx_sb_new(32); r[0]=(char)(long)v; r[1]=0; sx_sb_hdr(r)->len=1; return r; }");
  puts("static double sx_eq(const char *a,const char *b){ return strcmp(a?a:\"\",b?b:\"\")==0?1.0:0.0; }");
  puts("static double sx_idx(const char *s,double v){ long i=(long)v; long L=(long)strlen(s?s:\"\"); if(i<0)i+=L; if(i<0||i>=L){fputs(\"sx: index\\n\",stderr);exit(1);} return (double)(unsigned char)s[i]; }");
  puts("static int g_argc; static char **g_argv;");
  puts("static double sx_argc(void){ return (double)g_argc; }");
  puts("static char *sx_arg(int i){ return (i>=0&&i<g_argc)?sx_sb_from(g_argv[i]):sx_sb_new(1); }");
  puts("static char *sx_read(const char *p){ FILE *f=fopen(p,\"rb\"); if(!f) return sx_sb_new(1); fseek(f,0,SEEK_END); long n=ftell(f); fseek(f,0,SEEK_SET); char *b=malloc((size_t)n+1); size_t rd=fread(b,1,(size_t)n,f); b[rd]=0; fclose(f); char *r=sx_sb_from(b); free(b); return r; }");
  puts("static double sx_write(const char *p,const char *s){ FILE *f=fopen(p,\"wb\"); if(!f) return 0; fputs(s?s:\"\",f); fclose(f); return 1; }");
  emit_typedefs();
}

static void scan_structs(void){
  size_t save=P; nsd=0;
  while(P<N){
    skip(); if(P>=N) break;
    if(at("struct")){ parse_struct_def(); continue; }
    if(S[P]=='"'){ P++; while(P<N&&S[P]!='"'){ if(S[P]=='\\'&&P+1<N)P+=2; else P++; } if(P<N)P++; continue; }
    P++;
  }
  P=save;
}

static void collect(void){
  size_t save=P; nv=0;
  while(P<N){
    skip(); if(P>=N) break;
    if(at("struct")){ P+=6; free(parse_id()); skip_block(); continue; }
    if(at("make")){
      P+=4; free(parse_id()); skip(); eat("(");
      for(;;){ skip(); if(P<N&&S[P]==')'){P++;break;} free(parse_id()); skip(); if(P<N&&S[P]==','){P++;continue;} }
      skip_block(); continue;
    }
    if(at("hold")){
      P+=4; char *id=parse_id(); skip(); if(at("=")){ P++; skip();
        int ty=TY_NUM; int si=-1;
        if(P<N && S[P]=='"') ty=TY_STR;
        else if(P<N && S[P]=='[') ty=TY_LIST;
        else if(at("concat")||at("chr")||at("read_file")||at("arg")||at("sx_cat")||at("sx_chr")||at("sx_read")||at("sx_arg")) ty=TY_STR;
        else if(at("push")) ty=TY_LIST;
        else if(P<N && isid0(S[P])){
          char *t=parse_id();
          si=find_struct(t);
          if(si>=0) ty=TY_STRUCT;
          else {
            int i=findv(t); if(i>=0){ ty=vt[i]; si=vs[i]; }
            /* a postfix .field or [index] yields the element's type */
            if(P<N && S[P]=='.'){
              /* walk the whole .field chain: l.a.x keeps the nested type */
              int cur=(i>=0 && vt[i]==TY_STRUCT)?vs[i]:-1;
              while(P<N && S[P]=='.'){
                P++; char *fld=parse_id();
                ty=TY_NUM; si=-1;
                int ff=-1;
                if(cur>=0)
                  for(int f=0;f<SD[cur].nf;f++)
                    if(!strcmp(SD[cur].fields[f],fld)){ ff=f; break; }
                if(ff>=0){
                  if(SD[cur].fty[ff]==2){ ty=TY_STRUCT; si=SD[cur].fsi[ff]; }
                  else if(P<N && S[P]=='.'){
                    /* The link's type may simply be unknown YET: field types
                     * are fixed by struct literals, which scan_literals() only
                     * sees after this collect() pass.  Leave the chain
                     * unresolved for now -- a later pass re-types it once the
                     * literals have run (this is what makes a doubly nested
                     * copy `hold p2 = r.q.p` work), and the final emit parse
                     * still dies with a real error if the link truly is not a
                     * struct. */
                    ty=TY_NUM; si=-1;
                  }
                  else ty=SD[cur].fty[ff]?TY_STR:TY_NUM;
                }
                free(fld);
                cur=si;    /* only a nested struct keeps the chain going */
              }
              if(cur>=0){ si=cur; ty=TY_STRUCT; }   /* ended on a nested struct */
            } else if(P<N && S[P]=='['){
              /* skip to the matching ']' -- a list/string element is numeric */
              int d=1; P++;
              while(P<N && d){ if(S[P]=='[')d++; else if(S[P]==']')d--; P++; }
              ty=TY_NUM; si=-1;
            }
          }
          free(t);
        }
        if(ty==TY_STRUCT && si>=0) setv_struct(id, si);
        else setv(id,ty);
      }
      free(id); continue;
    }
    if(S[P]=='"'){ P++; while(P<N&&S[P]!='"'){ if(S[P]=='\\'&&P+1<N)P+=2; else P++; } if(P<N)P++; continue; }
    P++;
  }
  P=save;
}

/* ---- struct field type scan -------------------------------------------
 * The C typedef of a struct has to be printed before the body, but a
 * field's type is only known from the literals that fill it.  This pass
 * walks the whole program with the real expression parser (output is not
 * produced: expr() only returns text) so that every struct literal fixes
 * its field types before emit_typedefs() runs.  The first literal that
 * mentions a field decides; a conflicting later literal is a hard error.
 */
static void scan_stmt(void);
static void scan_body(void){
  skip(); eat("{");
  for(;;){ skip(); if(P>=N) die("}"); if(S[P]=='}'){ P++; return; } scan_stmt(); }
}
static void scan_stmt(void){
  skip(); if(P>=N||S[P]=='}') return;
  if(at("struct")){ P+=6; free(parse_id()); skip_block(); return; }
  if(at("make")){
    P+=4; char *mn=parse_id(); free(mn); skip(); eat("(");
    for(;;){ skip(); if(P<N&&S[P]==')'){P++;break;} char *pn=parse_id(); free(pn); skip(); if(P<N&&S[P]==','){P++;continue;} }
    scan_body(); return;
  }
  if(at("give")){ P+=4; int ty; char *e=expr(&ty); free(e); return; }
  if(at("hold")){ P+=4; char *n=parse_id(); skip(); eat("="); int ty; char *e=expr(&ty); free(e); free(n); return; }
  if(at("show")){ P+=4; int ty; char *e=expr(&ty); free(e); return; }
  if(at("when")){
    P+=4; int ty; char *c=expr(&ty); free(c); scan_body(); skip();
    if(at("otherwise")){ P+=9; scan_body(); }
    else if(at("else")){ P+=4; scan_body(); }
    return;
  }
  if(at("while")){ P+=5; int ty; char *c=expr(&ty); free(c); scan_body(); return; }
  die("stmt");
}
static void scan_literals(void){
  size_t save=P; P=0;
  while(P<N){ skip(); if(P>=N) break; scan_stmt(); }
  P=save;
}

static void decls(void){
  for(int i=0;i<nv;i++){
    if(vt[i]==TY_STR) printf("  char *%s = sx_sb_new(1);\n", vn[i]);
    else if(vt[i]==TY_LIST) printf("  sx_list *%s = 0;\n", vn[i]);
    else if(vt[i]==TY_STRUCT && vs[i]>=0) printf("  %s %s = {0};\n", SD[vs[i]].name, vn[i]);
    else printf("  double %s = 0;\n", vn[i]);
  }
}

int main(int argc, char **argv){
  if(argc<2){ fprintf(stderr,"Usage: sxc_seed_min <in.sa>\n"); return 1; }
  {                                    /* directory of the input file */
    const char *p=argv[1]; const char *sl=strrchr(p,'/');
    if(sl){ size_t d=(size_t)(sl-p)+1; USEDIR=malloc(d+1); memcpy(USEDIR,p,d); USEDIR[d]=0; }
  }
  {
    char *raw=read_all(argv[1]); if(!raw) die("open");
    S=expand_use(raw,0); free(raw);
    N=strlen(S);
  }
  P=0;
  scan_structs();
  /* struct field types come from literals, and literal values can name
   * variables whose type is only known after collect(); alternate both
   * until they are stable (4 rounds, same as the original collect budget) */
  for(int pass=0;pass<4;pass++){ collect(); scan_literals(); }
  P=0; preamble(); emit_all_fns();
  puts("int main(int argc,char **argv){ g_argc=argc; g_argv=argv;");
  decls(); P=0;
  while(P<N){ skip(); if(P>=N) break; stmt(); }
  puts("  return 0;\n}");
  return 0;
}
