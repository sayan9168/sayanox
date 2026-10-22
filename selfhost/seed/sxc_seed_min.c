/* sxc_seed_min.c — pure-min + make/give + lists + typed struct fields + use (modules)
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

/* Structural return proof; kept in sync with sxflow* in compiler_min.sa.
 * Loops may run zero times. Expressions are skipped, never constant-folded.
 * Ordinary expression/type validation is still performed by the frontend. */
static void rf_space(const char **p){
  for(;;){
    while(**p && isspace((unsigned char)**p)) ++*p;
    if((*p)[0]=='/' && (*p)[1]=='/'){
      while(**p && **p!='\n') ++*p;
    } else return;
  }
}
static void rf_word(const char **p, char word[64]){
  unsigned n=0;
  while(isalnum((unsigned char)**p) || **p=='_'){
    if(n<63) word[n++]=**p;
    ++*p;
  }
  word[n]=0;
}
static void rf_skip(const char **p, int mode){
  int nesting=0;
  while(**p){
    int c=(unsigned char)**p;
    if(c=='"'){
      ++*p;
      while(**p && **p!='"'){
        if(**p=='\\' && (*p)[1]) ++*p;
        ++*p;
      }
      if(**p) ++*p;
    } else if(c=='/' && (*p)[1]=='/'){
      while(**p && **p!='\n') ++*p;
    } else {
      if(!nesting && ((mode && c=='{') || (!mode && (c=='\n'||c=='\r'||c=='}')))) return;
      if(c=='(' || c=='[' || c=='{') nesting++;
      if(c==')' || c==']' || c=='}') nesting--;
      ++*p;
    }
  }
}
static int rf_block(const char **p, unsigned level){
  if(level>128){ while(**p) ++*p; return 0; }
  rf_space(p);
  if(**p!='{'){ while(**p) ++*p; return 0; }
  ++*p;
  int proven=0;
  while(**p){
    rf_space(p);
    if(**p=='}'){ ++*p; return proven; }
    if(!**p) break;
    char word[64]; rf_word(p,word);
    if(!strcmp(word,"when")){
      rf_skip(p,1);
      int all=rf_block(p,level+1), final_else=0;
      for(;;){
        const char *q=*p; rf_space(&q); char tail[64]; rf_word(&q,tail);
        int is_else=!strcmp(tail,"else") || !strcmp(tail,"otherwise");
        if(strcmp(tail,"elif") && !is_else) break;
        *p=q; rf_space(p);
        if(is_else){
          q=*p; rf_word(&q,tail);
          if(!strcmp(tail,"if") || !strcmp(tail,"when")) *p=q;
          else final_else=1;
        }
        rf_skip(p,1);
        int arm=rf_block(p,level+1);
        all=all && arm;
        if(final_else) break;
      }
      if(all && final_else) proven=1;
    } else if(!strcmp(word,"while") || !strcmp(word,"for")){
      rf_skip(p,1); (void)rf_block(p,level+1);
    } else {
      if(!strcmp(word,"give")) proven=1;
      rf_skip(p,0);
    }
  }
  return 0;
}


static char *list_seq_prefix;
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

static char *S; static size_t N, P, user_source_size;
enum { TY_NUM=0, TY_STR=1, TY_LIST=2, TY_STRUCT=3 };
enum { FT_NUM=0, FT_STR=1, FT_STRUCT=2, FT_LIST=3 };
static char *vn[2048]; static int vt[2048]; static int vs[2048];
static int nv;
/* -1 for inferred variables, otherwise an explicit num/str/list contract. */
static int vdecl[2048];
/* Struct identity for an explicit `hold p: Pt`; -1 for scalar/no annotation. */
static int vdecls[2048];
static int annotation_si=-1;
/* A for binder seen before the field-literal scan may have only a provisional
 * string kind. It is allowed one correction when the field kind becomes known. */
static int vdeferred[2048];
static int in_fn;
static int loop_depth;
static unsigned for_serial;
/* Only range headers treat adjacent dots as a delimiter, not a bad number. */
static int range_bound;
static int for_call, producer_ret=-1, function_ret=-1;
typedef struct {
  char *name, *params[16], *tp[8], *body;
  int pt[16], np, ret, annotated, ntp, template_id;
} Fn;
static Fn functions[512]; static int nfunctions, templates, generic_finalized;
/* Set once the collect/scan rounds are over. Struct field types are only
 * complete after the literal scan has run, so checks that depend on them
 * (a `for` source that names a field) are deferred to the emit passes:
 * an unresolved chain is not an error, it is simply not decided yet. */
static int types_final;

/* index of the struct the last atom() built (a struct literal); -1 otherwise.
 * Used to type a nested literal value while a struct literal is parsed. */
static int last_si = -1;

/* fty[f] is the C type of a field: FT_NUM = double, FT_STR = char *,
 * FT_STRUCT = a concrete nested struct, FT_LIST = sx_list *. fset[f] is 1
 * once a struct literal has fixed that field's type: the first
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
  size_t n=P-a; char *s=malloc(n+1); memcpy(s,S+a,n); s[n]=0;
  if(!strncmp(s,"_sx_iter_",9)) die("_sx_iter_ prefix is reserved for seed iteration temporaries");
  if(a<user_source_size && !strncmp(s,"_sx_gen_",8))
    die("_sx_gen_ prefix is reserved for seed generic specializations");
  return s;
}
static int findv(const char *n){ for(int i=0;i<nv;i++) if(!strcmp(vn[i],n)) return i; return -1; }
static int find_struct(const char *n){ for(int i=0;i<nsd;i++) if(!strcmp(SD[i].name,n)) return i; return -1; }

/* ---- generic struct templates -------------------------------------------
 * `struct Box<T> { v }` is a TEMPLATE: it owns a parameter list and field
 * NAMES but no layout, so it never enters SD. Every instantiation becomes an
 * ordinary concrete StructDef under a mangled name -- `Box<num>` is `Box__n`,
 * `Box<str>` is `Box__s`, `Pair<num,str>` is `Pair__ns` -- the same suffixes
 * generic FUNCTIONS already use, so one spelling of "specialisation" covers
 * both features in the emitted C.
 *
 * That mangling is what the design in docs/TYPES_ROADMAP.md asks for:
 *   * the mangled name is the type identity, so `Box<num>` and `Box<str>` are
 *     two different structs and can never share a field slot or a GC root;
 *   * each instantiation has its OWN StructDef, created on first use from the
 *     template's field names, so processing a literal never mutates the
 *     template's layout, and the field kinds of one instantiation are learned
 *     from its own literals exactly as for a concrete struct;
 *   * creation is idempotent (find_struct first), so the four collect/scan
 *     rounds agree on every struct index and the emitted C stays stable.
 * A type argument is num, str or list -- the three kinds function
 * specialisation uses. A struct name as a type argument is refused by name
 * rather than silently mangled into something the typedef order cannot carry.
 * ------------------------------------------------------------------------ */
typedef struct { char *name; char *p[8]; int np; char *fields[16]; int nf; } GStruct;
static GStruct GS[32]; static int ngs;
static int find_gstruct(const char *n){ for(int i=0;i<ngs;i++) if(!strcmp(GS[i].name,n)) return i; return -1; }
static char kind_letter(int k){ return k==TY_STR?'s':(k==TY_LIST?'l':'n'); }
/* how a struct field's type is named in a diagnostic */
static const char *ftyname(int si, int f){
  if(SD[si].fty[f]==FT_STR) return "a string";
  if(SD[si].fty[f]==FT_STRUCT) return "a struct";
  if(SD[si].fty[f]==FT_LIST) return "a list";
  return "a number";
}
static void setv(const char *n, int ty){
  int i=findv(n);
  if(i<0){ if(nv>=2048) die("too many vars"); vn[nv]=strdup(n); vt[nv]=ty; vs[nv]=-1; vdecl[nv]=-1; vdecls[nv]=-1; vdeferred[nv]=0; nv++; }
  else vt[i]=ty;
}
static void setv_struct(const char *n, int si){
  int i=findv(n);
  if(i<0){ if(nv>=2048) die("too many vars"); vn[nv]=strdup(n); vt[nv]=TY_STRUCT; vs[nv]=si; vdecl[nv]=-1; vdecls[nv]=-1; vdeferred[nv]=0; nv++; }
  else { vt[i]=TY_STRUCT; vs[i]=si; }
}
static int getty(const char *n){ int i=findv(n); return i<0?TY_NUM:vt[i]; }
static int getsi(const char *n){ int i=findv(n); return i<0?-1:vs[i]; }

/* All three passes read annotations with this parser. Collection fixes the
 * emitted storage type; the real expression passes check the entire RHS. */
static int hold_annotation(void){
  annotation_si=-1;
  skip();
  if(P>=N || S[P]!=':') return -1;
  if(in_fn && producer_ret<0) die("seed-min hold annotations require a fully typed make");
  P++; char *name=parse_id(); int ty=-1;
  if(!strcmp(name,"num")) ty=TY_NUM;
  else if(!strcmp(name,"str")) ty=TY_STR;
  else if(!strcmp(name,"list")) ty=TY_LIST;
  else {
    int si=find_struct(name);
    if(si>=0){ ty=TY_STRUCT; annotation_si=si; }
  }
  if(ty<0){
    char msg[512];
    snprintf(msg,sizeof msg,"unknown hold type '%s': seed-min supports num, str, list, or a declared struct name",name);
    die(msg);
  }
  free(name);
  return ty;
}
/* Register a name declared inside a make body. Struct literals carry their
 * type in the emitted text `((Name){...})`; extracting it here keeps the scan
 * pass and the emit pass in agreement, so a field chain resolves the same way
 * in both. */
static void register_local(const char *name,int ty,const char *text){
  if(ty!=TY_STRUCT){ setv(name,ty); return; }
  setv_struct(name,0);
  const char *p=text;
  if(p[0]=='('&&p[1]=='('){
    p+=2; char tname[64]; int ti=0;
    while(*p && *p!='{' && *p!=')' && ti<63) tname[ti++]=*p++;
    tname[ti]=0;
    int si=find_struct(tname);
    if(si>=0) setv_struct(name,si);
  }
}
static void check_hold_type(const char *name, int annotation, int actual, int actual_si){
  int vi=findv(name);
  int declared=vi<0?-1:vdecl[vi];
  int expected_si=-1;
  if(annotation>=0 && declared>=0 && annotation!=declared)
    die("conflicting hold type annotation");
  if((annotation>=0 && annotation!=actual) || (declared>=0 && declared!=actual))
    die("hold type mismatch: initializer/assignment disagrees with declared type");
  if(annotation==TY_STRUCT) expected_si=annotation_si;
  else if(declared==TY_STRUCT && vi>=0) expected_si=vdecls[vi];
  if(expected_si>=0 && (actual!=TY_STRUCT || actual_si!=expected_si)){
    char msg[256];
    snprintf(msg,sizeof msg,"hold '%s': initializer/assignment is not the declared struct %s",
             name,SD[expected_si].name);
    die(msg);
  }
}

/* Read all-or-nothing typed signatures consistently in every pass. */
static int signature_kind(Fn *f){
  char *t=parse_id(); int ty=-1;
  if(!strcmp(t,"num")) ty=TY_NUM;
  else if(!strcmp(t,"str")) ty=TY_STR;
  else if(!strcmp(t,"list")) ty=TY_LIST;
  for(int i=0;i<f->ntp;i++) if(!strcmp(t,f->tp[i])){ free(t); return -1-i; }
  free(t);
  if(ty<0) die("seed-min function type must be num, str, list or a declared type parameter");
  return ty;
}
static Fn function_header(void){
  Fn f={0}; f.ret=TY_NUM; f.template_id=-1; int typed=0;
  eat("make"); f.name=parse_id(); skip();
  if(at("<")){
    P++;
    for(;;){
      if(f.ntp>=8) die("seed-min generic type parameter limit is 8");
      char *t=parse_id();
      if(!strcmp(t,"num")||!strcmp(t,"str")||!strcmp(t,"list"))
        die("seed-min generic type parameter shadows a builtin type");
      for(int i=0;i<f.ntp;i++) if(!strcmp(t,f.tp[i])) die("seed-min duplicate type parameter");
      f.tp[f.ntp++]=t; skip();
      if(at(",")){ P++; continue; }
      eat(">"); break;
    }
  }
  eat("("); skip();
  if(!at(")")) for(;;){
    if(f.np>=16) die("seed-min function parameter limit is 16");
    f.params[f.np]=parse_id();
    for(int i=0;i<f.np;i++)
      if(!strcmp(f.params[i],f.params[f.np])) die("seed-min duplicate parameter name");
    skip(); f.pt[f.np]=TY_NUM;
    if(at(":")){ P++; f.pt[f.np]=signature_kind(&f); typed++; skip(); }
    f.np++;
    if(at(",")){ P++; continue; }
    break;
  }
  eat(")"); skip();
  if(at("->")){ P+=2; f.annotated=1; f.ret=signature_kind(&f); }
  if(typed && !f.annotated) die("seed-min typed make needs an explicit return type");
  if((typed || f.annotated) && typed!=f.np)
    die("seed-min typed make needs a type on every parameter");
  if(f.ntp){
    if(!f.annotated || f.ret>=0) die("seed-min generic return must name a type parameter");
    int used[8]={0};
    for(int i=0;i<f.np;i++){
      if(f.pt[i]>=0) die("seed-min generic parameters must name type parameters");
      used[-1-f.pt[i]]=1;
    }
    for(int i=0;i<f.ntp;i++) if(!used[i]) die("seed-min cannot infer unused type parameter");
  }
  return f;
}
static void free_header(Fn *f){
  free(f->name); for(int i=0;i<f->np;i++) free(f->params[i]);
  for(int i=0;i<f->ntp;i++) free(f->tp[i]); free(f->body);
}
static int findfn(const char *name){
  for(int i=0;i<nfunctions;i++) if(!strcmp(functions[i].name,name)) return i;
  return -1;
}
/* Demand-driven finite specialization worklist. Appending typed definitions
 * lets every ordinary scan/type-check/emission pass process the same body.
 * Source positions are offsets, never pointers retained across realloc. */
static const char *kind_word(int k){
  return k==TY_STR?"str":k==TY_LIST?"list":"num";
}
static int specialize(int fi,int n,int *types){
  Fn *t=&functions[fi]; int bind[8];
  for(int i=0;i<8;i++) bind[i]=-1;
  if(n!=t->np) die("seed-min generic argument count mismatch");
  for(int i=0;i<n;i++){
    int p=-1-t->pt[i], k=types[i];
    if(k!=TY_NUM && k!=TY_STR && k!=TY_LIST) die("seed-min generic arguments must be num, str or list");
    if(bind[p]>=0 && bind[p]!=k) die("seed-min generic type parameter has conflicting argument kinds");
    bind[p]=k;
  }
  for(int j=0;j<nfunctions;j++) if(functions[j].template_id==fi){
    int same=1;
    for(int i=0;i<n;i++) if(functions[j].pt[i]!=types[i]) same=0;
    if(same) return j;
  }
  if(generic_finalized) die("seed-min generic call was not resolved before emission");
  if(nfunctions>=512) die("seed-min function/specialization limit is 512");
  size_t bl=strlen(t->body);
  if(bl>2*1024*1024 || N>8*1024*1024) die("seed-min generic expansion exceeds source limit");
  size_t capacity=bl*4+4096;
  for(int i=0;i<n;i++){
    size_t z=strlen(t->params[i]);
    if(capacity>8*1024*1024 || z>8*1024*1024-capacity)
      die("seed-min generic generated definition exceeds 8 MiB");
    capacity+=z;
  }
  char *text=malloc(capacity); if(!text) die("generic allocation");
  int index=nfunctions++; Fn *f=&functions[index];
  memset(f,0,sizeof *f); f->template_id=fi; f->annotated=1; f->np=n;
  char name[64]; snprintf(name,sizeof name,"_sx_gen_%d_%d",fi,index);
  f->name=strdup(name); f->ret=bind[-1-t->ret];
  size_t o=(size_t)sprintf(text,"\nmake %s(",name);
  for(int i=0;i<n;i++){
    f->params[i]=strdup(t->params[i]); f->pt[i]=types[i];
    o+=(size_t)sprintf(text+o,"%s%s: %s",i?", ":"",f->params[i],kind_word(types[i]));
  }
  o+=(size_t)sprintf(text+o,") -> %s ",kind_word(f->ret));
  /* Substitute only type-annotation tokens; never strings, comments or
   * ordinary variable names that happen to match a type parameter. */
  int annotation=0;
  for(size_t q=0;q<bl;){
    if(t->body[q]=='"'){
      text[o++]=t->body[q++];
      while(q<bl){ char c=t->body[q++]; text[o++]=c;
        if(c=='\\' && q<bl) text[o++]=t->body[q++]; else if(c=='"') break;
      }
      annotation=0; continue;
    }
    if(q+1<bl && t->body[q]=='/' && t->body[q+1]=='/'){
      while(q<bl && t->body[q]!='\n') text[o++]=t->body[q++];
      continue;
    }
    if(isid0(t->body[q])){
      size_t a=q; while(q<bl && isid(t->body[q])) q++;
      if(q-a>=8 && !memcmp(t->body+a,"_sx_gen_",8))
        die("_sx_gen_ prefix is reserved for seed generic specializations");
      int p=-1;
      if(annotation) for(int j=0;j<t->ntp;j++)
        if(strlen(t->tp[j])==q-a && !memcmp(t->body+a,t->tp[j],q-a)) p=j;
      if(p>=0){ const char *k=kind_word(bind[p]); size_t z=strlen(k); memcpy(text+o,k,z); o+=z; }
      else { memcpy(text+o,t->body+a,q-a); o+=q-a; }
      annotation=0; continue;
    }
    char c=t->body[q++]; text[o++]=c;
    if(!isspace((unsigned char)c)) annotation=c==':';
  }
  text[o++]='\n'; text[o]=0;
  if(o>8*1024*1024 || N>8*1024*1024-o) die("seed-min generic expansion exceeds 8 MiB");
  char *expanded=realloc(S,N+o+1); if(!expanded) die("generic allocation");
  S=expanded; memcpy(S+N,text,o+1); N+=o; free(text);
  return index;
}
static const char *ctype(int ty){
  return ty==TY_STR?"char *":ty==TY_LIST?"sx_list *":"double ";
}
/* Every function body -- typed producer OR legacy untyped make -- gets an
 * isolated symbol table. Two reasons, both about generated C:
 *   1. top-level `hold` names are emitted as locals of main(), so a function
 *      body cannot see them. Before isolation an untyped make silently
 *      emitted a bare global name into the function body, which is not a
 *      language error but a C "undeclared identifier" failure. Now the name
 *      is simply not in scope and the compiler reports it (see atom()).
 *   2. a local that happens to share a global's name must not reuse the
 *      global's slot or its type.
 * enter_scope()/leave_scope() do the save/restore; the producer wrappers add
 * the return-type contract on top. */
typedef struct { char *names[2048]; int types[2048], structs[2048], declared[2048], declared_structs[2048], deferred[2048], count; } Env;
static Env *enter_scope(void){
  Env *e=malloc(sizeof *e); if(!e) exit(1);
  memcpy(e->names,vn,sizeof vn); memcpy(e->types,vt,sizeof vt);
  memcpy(e->structs,vs,sizeof vs); memcpy(e->declared,vdecl,sizeof vdecl);
  memcpy(e->declared_structs,vdecls,sizeof vdecls); memcpy(e->deferred,vdeferred,sizeof vdeferred);
  e->count=nv; nv=0; return e;
}
static void leave_scope(Env *e){
  for(int i=0;i<nv;i++) free(vn[i]);
  memcpy(vn,e->names,sizeof vn); memcpy(vt,e->types,sizeof vt);
  memcpy(vs,e->structs,sizeof vs); memcpy(vdecl,e->declared,sizeof vdecl);
  memcpy(vdecls,e->declared_structs,sizeof vdecls); memcpy(vdeferred,e->deferred,sizeof vdeferred);
  nv=e->count; free(e);
}
static Env *enter_producer(int ret){ Env *e=enter_scope(); producer_ret=ret; return e; }
static void leave_producer(Env *e){ leave_scope(e); producer_ret=-1; }
/* Validate builtin calls only in the new checked contexts; legacy pure-min
 * lowering stays unchanged. Kind 4 here means string-or-list. */
static void check_call(const char *name,int n,int *types){
  int arity=-1, a=-1, b=-1, fi=findfn(name);
  if(!strcmp(name,"concat")){ arity=2; a=b=TY_STR; }
  else if(!strcmp(name,"chr")||!strcmp(name,"sx_chr")||!strcmp(name,"arg")||!strcmp(name,"sx_arg")){ arity=1; a=TY_NUM; }
  else if(!strcmp(name,"read_file")||!strcmp(name,"sx_read")||!strcmp(name,"http_get")||!strcmp(name,"sx_http")){ arity=1; a=TY_STR; }
  else if(!strcmp(name,"push")){ arity=2; a=TY_LIST; b=TY_NUM; }
  else if(!strcmp(name,"len")||!strcmp(name,"sx_len")){ arity=1; a=4; }
  else if(!strcmp(name,"sx_index")||!strcmp(name,"sx_idx")||!strcmp(name,"index")){ arity=2; a=4; b=TY_NUM; }
  else if(!strcmp(name,"string_eq")||!strcmp(name,"sx_eq")||!strcmp(name,"write_file")||!strcmp(name,"sx_write")){ arity=2; a=b=TY_STR; }
  else if(!strcmp(name,"arg_count")||!strcmp(name,"sx_argc")){ arity=0; }
  else if(!strcmp(name,"gc")||!strcmp(name,"sx_gc_run")||!strcmp(name,"gc_live")
       ||!strcmp(name,"sx_gc_live")||!strcmp(name,"gc_runs")||!strcmp(name,"sx_gc_count")){ arity=0; }
  else if(fi>=0){
    if(n!=functions[fi].np) die("seed-min call argument count does not match function signature");
    for(int i=0;i<n;i++) if(types[i]!=functions[fi].pt[i]) die("seed-min function argument type does not match signature");
    return;
  } else die("seed-min for/producer call names an unknown or unsupported function");
  if(n!=arity) die("seed-min for/producer builtin argument count mismatch");
  if(n>0 && (a==4 ? types[0]!=TY_STR && types[0]!=TY_LIST : types[0]!=a))
    die("seed-min for/producer builtin argument type mismatch");
  if(n>1 && types[1]!=b) die("seed-min for/producer builtin argument type mismatch");
}

static char *expr(int *oty);
static void stmt(void);
static void block(void);
static int resolve_base_si(const char *base);
static int field_type(const char *base, const char *fld, int *osi);
static void skip_block(void);   /* defined below; skip_struct_decl needs it */

/* `struct Box<T> { ... }` -- a struct declaration with a type parameter list --
 * is generic-struct syntax, and no backend implements it: a struct's field
 * layout is learned from literals and owned by ONE global definition, so
 * Box<num> and Box<str> would share field slots and confuse field loads and
 * the collector's roots (docs/TYPES_ROADMAP.md, "Why generic structs are not
 * implemented here"). Refuse it by name. Without this the '<' is left where the
 * scanner expects '{', and every path below died as `seed_min: { at <char
 * offset>` -- a diagnostic that names a brace and an offset instead of the
 * feature that is missing. */
/* Parse `<T>` / `<A, B>` after a struct name. Returns the parameter count, or
 * 0 when there is no list at all, which is how a concrete declaration is told
 * from a template. Names are strdup'd into `out` (caller frees). */
static int parse_type_params(char **out, int max){
  skip();
  if(P>=N || S[P]!='<') return 0;
  P++;
  int n=0;
  for(;;){
    skip();
    if(P>=N) die("a generic struct type parameter list needs a closing >");
    if(S[P]=='>'){ P++; break; }
    if(S[P]==','){ P++; continue; }
    if(n>=max) die("too many type parameters (seed-min limit is 8)");
    out[n++]=parse_id();
  }
  return n;
}
/* the shape every early scan path uses for a struct declaration it is not
 * collecting: eat the name, eat a type parameter list if there is one, skip
 * the body. Templates are registered by scan_structs/parse_struct_def, so a
 * scan path only has to get past the syntax. */
static void skip_struct_decl(void){
  free(parse_id());
  char *tp[8]; int ntp=parse_type_params(tp,8);
  for(int i=0;i<ntp;i++) free(tp[i]);
  skip_block();
}

/* `Box<num>` at an expression site: read the type arguments, then return the
 * concrete StructDef index of that instantiation, creating it from the
 * template on first use. `nk` receives the argument kinds so the literal can
 * check them (field i takes parameter i's kind when the counts match). */
static int instantiate_gstruct(int gi, int *nk, int *nks){
  skip();
  if(P>=N || S[P]!='<'){
    char m[256];
    snprintf(m,sizeof m,"%s is a generic struct: write %s<num> { ... } with one type argument per type parameter",
             GS[gi].name, GS[gi].name);
    die(m);
  }
  P++;
  int ks[8]; int kstruct[8]; int n=0; int nested=0;
  char code[8][96];
  for(;;){
    skip();
    if(P>=N) die("a type argument list needs a closing >");
    if(S[P]=='>'){ P++; break; }
    if(S[P]==','){ P++; continue; }
    if(n>=8) die("too many type arguments (seed-min limit is 8)");
    char *t=parse_id();
    /* A nested instantiation -- `Box<Box<num>>` -- is the type argument that
     * makes this feature recursive. Build the INNER instantiation first: its
     * StructDef then has a lower index than the outer one, which is exactly
     * the order the emitted C typedefs need, and the nested-literal check
     * below (last_si < si) is satisfied without a second sort. */
    skip();
    if(P<N && S[P]=='<' && find_gstruct(t)>=0){
      int subk[8], subs[8];
      int inner=instantiate_gstruct(find_gstruct(t),subk,subs);
      free(t);
      ks[n]=TY_STRUCT; kstruct[n]=inner; nested=1;
      snprintf(code[n],sizeof code[n],"%s",SD[inner].name);
      n++;
      continue;
    }
    int k=-1;
    if(!strcmp(t,"num")) k=TY_NUM;
    else if(!strcmp(t,"str")) k=TY_STR;
    else if(!strcmp(t,"list")) k=TY_LIST;
    if(k<0){
      char m[256];
      snprintf(m,sizeof m,"a type argument must be num, str, list or an instantiation of a generic struct (got '%s')", t);
      free(t); die(m);
    }
    free(t);
    ks[n]=k; kstruct[n]=-1;
    code[n][0]=(char)kind_letter(k); code[n][1]=0;
    n++;
  }
  if(n!=GS[gi].np){
    char m[256];
    snprintf(m,sizeof m,"%s takes %d type argument%s, got %d",
             GS[gi].name, GS[gi].np, GS[gi].np==1?"":"s", n);
    die(m);
  }
  /* The suffix is one letter per primitive argument, or the inner mangled
   * name for a nested one. Arguments run together while they are all single
   * letters, so `Pair<num, str>` is still `Pair__ns`; as soon as one is
   * nested they are separated by '_', which keeps `Pair<Box<num>, str>`
   * (`Pair__Box__n_s`) readable and free of collisions. */
  char mn[192];
  int o=snprintf(mn,sizeof mn,"%s__",GS[gi].name);
  for(int i=0;i<n;i++){
    nk[i]=ks[i]; if(nks) nks[i]=kstruct[i];
    if(nested && i && o<(int)sizeof mn-1) mn[o++]='_';
    for(const char *cc=code[i]; *cc && o<(int)sizeof mn-1; cc++) mn[o++]=*cc;
  }
  mn[o]=0;
  int si=find_struct(mn);
  if(si>=0){ skip(); return si; }        /* already instantiated: reuse it */
  if(nsd>=32) die("too many structs (a generic instantiation counts as one)");
  StructDef *D=&SD[nsd];
  D->name=strdup(mn);
  D->nf=GS[gi].nf;
  for(int f=0;f<D->nf;f++) D->fields[f]=strdup(GS[gi].fields[f]);
  memset(D->fty,0,sizeof D->fty);
  memset(D->fset,0,sizeof D->fset);
  for(int i=0;i<16;i++) D->fsi[i]=-1;
  nsd++;
  skip();
  return nsd-1;
}

static void parse_struct_def(void){
  eat("struct");
  char *name=parse_id();
  char *tp[8]; int ntp=parse_type_params(tp,8);
  if(ntp>0){
    /* A template: field names only, and no StructDef. Every instantiation gets
       its own layout, so nothing here may be mutated by a literal later. */
    if(find_gstruct(name)>=0 || find_struct(name)>=0){
      free(name); for(int i=0;i<ntp;i++) free(tp[i]);
      skip(); eat("{"); int d=1; P++;
      while(P<N&&d){ if(S[P]=='{')d++; else if(S[P]=='}')d--; P++; }
      return;
    }
    if(ngs>=32) die("too many generic structs");
    GStruct *G=&GS[ngs];
    G->name=name; G->np=ntp; G->nf=0;
    for(int i=0;i<ntp;i++) G->p[i]=tp[i];
    skip(); eat("{");
    for(;;){
      skip();
      if(P>=N) die("}");
      if(S[P]=='}'){ P++; break; }
      if(S[P]==','){ P++; continue; }
      if(!isid0(S[P])){ P++; continue; }
      if(G->nf>=16) die("too many fields");
      G->fields[G->nf++]=parse_id();
      skip(); if(P<N&&S[P]==':'){ size_t z=P+1; while(z<N&&(S[z]==' '||S[z]=='\t')) z++; if(z<N&&isid0(S[z])) die("struct field annotations are not supported: write just the field name (docs/TYPES_ROADMAP.md)"); }
    }
    ngs++;
    return;
  }
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
    skip(); if(P<N&&S[P]==':'){ size_t z=P+1; while(z<N&&(S[z]==' '||S[z]=='\t')) z++; if(z<N&&isid0(S[z])) die("struct field annotations are not supported: write just the field name (docs/TYPES_ROADMAP.md)"); }
  }
  nsd++;
}

static char *atom(int *oty){
  skip(); last_si = -1;
  if(at("true")){ P+=4; *oty=TY_NUM; return strdup("1"); }
  if(at("false")){ P+=5; *oty=TY_NUM; return strdup("0"); }
  if(P<N && S[P]=='('){ P++; char *e=expr(oty); skip(); if(P>=N||S[P]!=')') die(")"); P++; return e; }
  if(P<N && S[P]=='['){
    P++; char *els[64]; int ne=0; skip();
    if(P>=N||S[P]!=']'){
      for(;;){
        int et; els[ne++]=expr(&et); if(ne>=64) die("list too big");
        if(et==TY_STRUCT) die("a list cannot hold a struct value");
        if(et!=TY_NUM) die("list elements must be numbers (a list cannot hold a string or a list)");
        skip(); if(P<N&&S[P]==','){P++;skip();continue;} break;
      }
    }
    skip(); if(P>=N||S[P]!=']') die("]"); P++;
    /* C does not order varargs. Comma-sequenced builder calls do, and a
     * linked stack of in-progress lists keeps nested/recursive construction
     * reentrant without hoisting evaluation out of a condition. */
    size_t plen=strlen(list_seq_prefix), need=128+4*plen;
    for(int i=0;i<ne;i++) need+=strlen(els[i])+plen+40;
    char *buf=malloc(need); if(!buf) die("list expression allocation");
    size_t o=0; o+=snprintf(buf+o,need,"(%s_begin(%d)",list_seq_prefix,ne);
    for(int i=0;i<ne;i++) o+=snprintf(buf+o,need-o,",%s_add((double)(%s))",list_seq_prefix,els[i]);
    snprintf(buf+o,need-o,",%s_end())",list_seq_prefix);
    for(int i=0;i<ne;i++) free(els[i]);
    *oty=TY_LIST; return buf;
  }
  if(P<N && S[P]=='"'){
    P++; size_t a=P; while(P<N && S[P]!='"'){ if(S[P]=='\\' && P+1<N) P+=2; else P++; }
    size_t n=P-a; if(P<N && S[P]=='"') P++;
    char *r=malloc(n+3); r[0]='"'; memcpy(r+1,S+a,n); r[1+n]='"'; r[2+n]=0; *oty=TY_STR; return r;
  }
  /* number literal: digits with an optional fraction (2.5).  The `.` is only
   * part of the number when a digit follows it, so it is never mistaken for
   * a field access; C reads the copied text as a double literal. */
  if(P<N && (((S[P]=='-'||S[P]=='+') && P+1<N && isdigit((unsigned char)S[P+1])) || isdigit((unsigned char)S[P]))){
    size_t a=P; if(!isdigit((unsigned char)S[P])) P++;
    while(P<N && isdigit((unsigned char)S[P])) P++;
    if(P+1<N && S[P]=='.' && isdigit((unsigned char)S[P+1])){
      P++; while(P<N && isdigit((unsigned char)S[P])) P++;
    }
    if(P<N && ((S[P]=='.' && !(range_bound && at(".."))) || isid0(S[P]))) die("malformed number literal");
    size_t n=P-a;
    int fractional=0;
    for(size_t i=a;i<P;i++) if(S[i]=='.') fractional=1;
    /* C treats an integer token as `int`, so a constant-only expression such
     * as 100000 * 100000 overflows before it can be assigned to a `double`.
     * Give every integer literal a floating spelling at the source boundary;
     * this also keeps conditions and function returns on IEEE-double math. */
    char *r=malloc(n+(fractional?1:3));
    memcpy(r,S+a,n);
    if(fractional) r[n]=0;
    else { r[n]='.'; r[n+1]='0'; r[n+2]=0; }
    *oty=TY_NUM; return r;
  }
  if(P<N && isid0(S[P])){
    char *id=parse_id(); skip();
    if(range_bound){
      if(P<N && S[P]=='('){
        if(strcmp(id,"len") && strcmp(id,"sx_len"))
          die("seed-min for range bounds support len(...) but not other calls yet");
      } else if(findv(id)<0) die("seed-min for range bound names an undefined variable");
    }
    /* A generic instantiation first: `Box<num> { ... }` becomes the concrete
       struct `Box__n`, so the literal path below is the ordinary one. */
    int gk[8]; int gks[8]; int ngk=0;
    for(int gz=0;gz<8;gz++) gks[gz]=-1;
    if(find_struct(id)<0){
      int gi=find_gstruct(id);
      if(gi>=0){
        if(P<N && S[P]=='<'){
          int gsi=instantiate_gstruct(gi,gk,gks);
          ngk=GS[gi].np;
          char *mn=strdup(SD[gsi].name);
          free(id); id=mn;
        } else {
          char m[256];
          snprintf(m,sizeof m,"%s is a generic struct: write %s<num> { ... } with one type argument per type parameter", id, id);
          die(m);
        }
      }
    }
    /* A struct name followed by `{` is a literal, not a variable reference. */
    int struct_literal=find_struct(id)>=0 && P<N && S[P]=='{';
    if((for_call || producer_ret>=0 || in_fn) && !(P<N && S[P]=='(') && !struct_literal && findv(id)<0){
      /* A function body has its own scope in the generated C: top-level hold
       * names live in main() and are not visible there. Reporting the name is
       * the honest behaviour; emitting it used to produce C that failed with
       * "undeclared identifier" instead of a Sayanox diagnostic. */
      if(in_fn && producer_ret<0 && !for_call)
        die("seed-min make body names an undefined variable: a body cannot capture top-level hold names, pass them as parameters");
      die("seed-min for/producer expression names an undefined variable");
    }
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
          /* When a template has as many fields as type parameters, field i
             takes parameter i's kind: `Box<num> { "seven" }` is an error, not
             a string field in a box that claimed to hold numbers. With a
             different count the kinds stay learned from the literals, as for
             a concrete struct. */
          if(ngk>0 && ngk==SD[si].nf && fi<ngk && et!=gk[fi]
             && (et==TY_NUM || et==TY_STR || et==TY_LIST)){
            char msg[256];
            snprintf(msg,sizeof msg,"%s field '%s' is %s (its type argument says so), the literal gives %s",
                     SD[si].name, SD[si].fields[fi],
                     gk[fi]==TY_STRUCT ? (gks[fi]>=0 ? SD[gks[fi]].name : "a struct")
                                       : kind_word(gk[fi]),
                     kind_word(et));
            die(msg);
          }
          /* A nested type argument also fixes WHICH struct the field holds:
             `Box<Box<num>> { Box<str> { "x" } }` is the same class of error as
             `Box<num> { "seven" }`, and naming both mangled types is the only
             way the message stays readable. */
          if(ngk>0 && ngk==SD[si].nf && fi<ngk && gk[fi]==TY_STRUCT && et==TY_STRUCT
             && gks[fi]>=0 && last_si>=0 && last_si!=gks[fi]){
            char msg[256];
            snprintf(msg,sizeof msg,"%s field '%s' is a %s (its type argument says so), the literal gives a %s",
                     SD[si].name, SD[si].fields[fi], SD[gks[fi]].name, SD[last_si].name);
            die(msg);
          }
          if(et==TY_STR || et==TY_NUM){
            int ft=(et==TY_STR)?FT_STR:FT_NUM;
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
            if(SD[si].fset[fi] && (SD[si].fty[fi]!=FT_STRUCT || SD[si].fsi[fi]!=last_si)){
              char msg[256];
              snprintf(msg,sizeof msg,"struct %s field '%s' is a struct here, %s in an earlier literal",
                       SD[si].name, SD[si].fields[fi], ftyname(si,fi));
              die(msg);
            }
            SD[si].fty[fi]=FT_STRUCT; SD[si].fsi[fi]=last_si; SD[si].fset[fi]=1;
          } else if(et==TY_LIST){
            if(SD[si].fset[fi] && SD[si].fty[fi]!=FT_LIST){
              char msg[256];
              snprintf(msg,sizeof msg,"struct %s field '%s' is a list here, %s in an earlier literal",
                       SD[si].name, SD[si].fields[fi], ftyname(si,fi));
              die(msg);
            }
            /* Store the list pointer, never its elements: aliases are preserved. */
            SD[si].fty[fi]=FT_LIST; SD[si].fsi[fi]=-1; SD[si].fset[fi]=1;
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
        if(!val && SD[si].fset[f] && SD[si].fty[f]==FT_STRUCT){
          char msg[256];
          snprintf(msg,sizeof msg,"struct %s field '%s' is a struct and must be filled in every literal",
                   SD[si].name, SD[si].fields[f]);
          die(msg);
        }
        if(!val){
          if(SD[si].fty[f]==FT_STR) val="\"\"";
          else if(SD[si].fty[f]==FT_LIST) val="NULL";
          else val="0";
        }
        o+=snprintf(buf+o,need-o,"%s%s", f?",":"", val);
      }
      snprintf(buf+o,need-o,"})");
      for(int f=0;f<16;f++) free(slot[f]);
      free(id); *oty=TY_STRUCT; last_si=si; return buf;
    }
    if(P<N && S[P]=='('){
      int fi=findfn(id), typed_call=fi>=0 && functions[fi].annotated;
      /* Check nested expressions as well as the outer ABI: f(concat(1,2))
       * must not pass just because concat is nominally string-returning. */
      if(typed_call) for_call++;
      P++; char *args[16]; int aty[16]; int na=0; skip();
      if(P>=N||S[P]!=')'){
        for(;;){ if(na>=16) die("seed-min call argument limit is 16"); args[na]=expr(&aty[na]); na++; skip(); if(P<N&&S[P]==','){P++;skip();continue;} break; }
      }
      if(P>=N||S[P]!=')') die(")"); P++;
      char buf[65536];
      size_t call_bytes=strlen(id)+128;
      for(int i=0;i<na;i++){
        if(call_bytes>=sizeof buf || strlen(args[i])>=sizeof buf-call_bytes)
          die("seed-min call expression exceeds the 64 KiB lowering limit");
        call_bytes+=strlen(args[i])+4;
      }
      if(call_bytes>=sizeof buf) die("seed-min call expression exceeds the 64 KiB lowering limit");
      if(fi>=0 && functions[fi].ntp){
        fi=specialize(fi,na,aty); free(id); id=strdup(functions[fi].name);
      }
      if(for_call || producer_ret>=0) check_call(id,na,aty);
      if(typed_call) for_call--;
      if(range_bound && na!=1) die("seed-min for range len requires one argument");
      if(!strcmp(id,"concat")&&na==2){
        snprintf(buf,sizeof buf,"sx_cat(%s,%s)",args[0],args[1]); *oty=TY_STR;
      } else if((!strcmp(id,"len")||!strcmp(id,"sx_len"))&&na==1){
        if(range_bound && aty[0]!=TY_LIST && aty[0]!=TY_STR)
          die("seed-min for range len operand must be a list or string");
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
      } else if((!strcmp(id,"gc")||!strcmp(id,"sx_gc_run"))&&na==0){
        snprintf(buf,sizeof buf,"sx_gc_run()"); *oty=TY_NUM;
      } else if((!strcmp(id,"gc_live")||!strcmp(id,"sx_gc_live"))&&na==0){
        snprintf(buf,sizeof buf,"sx_gc_live()"); *oty=TY_NUM;
      } else if((!strcmp(id,"gc_runs")||!strcmp(id,"sx_gc_count"))&&na==0){
        snprintf(buf,sizeof buf,"sx_gc_count()"); *oty=TY_NUM;
      } else if((!strcmp(id,"read_file")||!strcmp(id,"sx_read"))&&na==1){
        snprintf(buf,sizeof buf,"sx_read(%s)",args[0]); *oty=TY_STR;
      } else if((!strcmp(id,"http_get")||!strcmp(id,"sx_http"))&&na==1){
        snprintf(buf,sizeof buf,"sx_http(%s)",args[0]); *oty=TY_STR;
      } else if((!strcmp(id,"write_file")||!strcmp(id,"sx_write"))&&na==2){
        snprintf(buf,sizeof buf,"sx_write(%s,%s)",args[0],args[1]); *oty=TY_NUM;
      } else if(!strcmp(id,"push")&&na==2){
        snprintf(buf,sizeof buf,"sx_lpush(%s,(double)(%s))",args[0],args[1]); *oty=TY_LIST;
      } else {
        int fi=findfn(id);
        /* Not a builtin and not a declared make: copying the name into the C
         * output used to leave the C compiler/linker to report it (an unknown
         * `gc()` became an implicit declaration). Sayanox reports it instead. */
        if(fi<0) die("seed-min call names an unknown function or builtin");
        size_t o=0; o+=snprintf(buf+o,sizeof buf-o,"%s(",id);
        for(int i=0;i<na;i++) o+=snprintf(buf+o,sizeof buf-o,"%s%s",i?",":"",args[i]);
        snprintf(buf+o,sizeof buf-o,")");
        *oty=functions[fi].ret;
      }
      for(int i=0;i<na;i++) free(args[i]);
      free(id); return strdup(buf);
    }
    *oty=getty(id);
    if(*oty==TY_STRUCT) last_si=getsi(id);
    return id;
  }
  die("primary"); return 0;
}

static char *primary(int *oty){
  char *l=atom(oty);
  for(;;){
    skip();
    if(P<N && S[P]=='['){
      P++; int it; char *ix=expr(&it); skip();
      if((range_bound || for_call || producer_ret>=0) && it!=TY_NUM) die("seed-min for range index must be a number");
      if(P>=N||S[P]!=']') die("]"); P++;
      char *t=malloc(strlen(l)+strlen(ix)+24);
      if(*oty==TY_LIST){ sprintf(t,"sx_lget(%s,%s)",l,ix); *oty=TY_NUM; }
      else if(*oty==TY_STR){ sprintf(t,"sx_idx(%s,%s)",l,ix); *oty=TY_NUM; }
      else die("index on non-list/str");
      free(l); free(ix); l=t;
    } else if(P<N && S[P]=='.' && !(range_bound && at(".."))){
      P++; char *fld=parse_id();
      if(range_bound || for_call || producer_ret>=0){
        int si=resolve_base_si(l), found=0;
        if(*oty!=TY_STRUCT || si<0) die("seed-min checked field access requires a named struct or field chain");
        for(int f=0;f<SD[si].nf;f++) if(!strcmp(SD[si].fields[f],fld)) found=1;
        if(!found) die("seed-min unknown struct field in checked expression");
      }
      int fsi=-1;
      int ft=field_type(l,fld,&fsi);
      char *t=malloc(strlen(l)+strlen(fld)+4);
      sprintf(t,"%s.%s",l,fld);
      free(l); free(fld); l=t; *oty=ft;
      last_si=ft==TY_STRUCT?fsi:-1;
    } else break;
  }
  return l;
}

static char *unary(int *oty){
  skip();
  if(P<N && S[P]=='-'){ P++; char *e=unary(oty); if((range_bound || for_call || producer_ret>=0) && *oty!=TY_NUM) die("seed-min for range unary minus needs a number"); char *t=malloc(strlen(e)+4); sprintf(t,"(-%s)",e); free(e); *oty=TY_NUM; return t; }
  return primary(oty);
}

static char *mul(int *oty){
  char *l=unary(oty);
  for(;;){
    skip(); char op=0;
    if(P<N && (S[P]=='*'||S[P]=='/'||S[P]=='%')){ op=S[P]; P++; }
    else break;
    int rt; char *r=unary(&rt);
    /* lists, structs and strings are pointers in the C output: `xs * 2` is
     * either a C error or (for + and -) silent pointer arithmetic */
    if(*oty!=TY_NUM||rt!=TY_NUM) die("* / % need numbers (not a string, list or struct)");
    if(op=='%'){
      /* sx_mod preserves truncation-toward-zero semantics and turns a zero
       * divisor into a deterministic language error instead of SIGFPE. */
      char *t=malloc(strlen(l)+strlen(r)+32);
      sprintf(t,"sx_mod((double)(%s),(double)(%s))",l,r);
      free(l); free(r); l=t; *oty=TY_NUM;
    } else if(op=='/'){
      /* always a double division: two integer literals (10 / 4) would
       * otherwise be C integer division and print 2 instead of 2.5 */
      char *t=malloc(strlen(l)+strlen(r)+16); sprintf(t,"((double)(%s)/%s)",l,r); free(l); free(r); l=t; *oty=TY_NUM;
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
    if(*oty==TY_LIST||rt==TY_LIST||*oty==TY_STRUCT||rt==TY_STRUCT)
      die("+ and - need numbers or strings (not a list or struct; hold ys = xs copies a whole list)");
    if((*oty==TY_STR||rt==TY_STR)&&op=='-') die("- needs numbers (a string cannot be subtracted)");
    if((*oty==TY_STR)!=(rt==TY_STR)) die("+ joins two strings or adds two numbers (a string + a number is not in the pure-min subset)");
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
  int lt=*oty;
  skip();
  int op=0, olen=0;
  if(P+1<N && S[P]=='='&&S[P+1]=='='){ op=1; olen=2; }
  else if(P+1<N && S[P]=='!'&&S[P+1]=='='){ op=2; olen=2; }
  else if(P+1<N && S[P]=='<'&&S[P+1]=='='){ op=3; olen=2; }
  else if(P+1<N && S[P]=='>'&&S[P+1]=='='){ op=4; olen=2; }
  else if(P<N && S[P]=='<'){ op=5; olen=1; }
  else if(P<N && S[P]=='>'){ op=6; olen=1; }
  if(!op) return l;
  static const char *cops[]={"","==","!=","<=",">=","<",">"};
  P+=olen;
  int rt; char *r=add(&rt);
  if((range_bound || for_call || producer_ret>=0) && (lt==TY_LIST || lt==TY_STRUCT || rt==TY_LIST || rt==TY_STRUCT))
    die("seed-min for range cannot compare lists or structs");
  char *t;
  if(lt==TY_STR || rt==TY_STR){
    /* strings compare by content (strcmp), never by address */
    if(lt!=TY_STR || rt!=TY_STR) die("a string can only be compared with a string (not a number, list or struct)");
    t=malloc(strlen(l)+strlen(r)+48);
    sprintf(t,"((strcmp(%s,%s))%s0)",l,r,cops[op]);
  } else {
    t=malloc(strlen(l)+strlen(r)+24);
    sprintf(t,"((%s)%s(%s))",l,cops[op],r);
  }
  free(l); free(r); *oty=TY_NUM; return t;
}

/* Word not binds below comparison, above and/or. */
static char *not_(int *oty){
  skip();
  if(at("not")){
    P+=3; char *e=not_(oty);
    if(*oty!=TY_NUM) die("not operand must be a number");
    char *r=malloc(strlen(e)+8); sprintf(r,"(!(%s))",e); free(e);
    return r;
  }
  return cmp_(oty);
}
static char *and_(int *oty){
  char *l=not_(oty);
  for(;;){
    skip();
    if(at("and")) P+=3;
    else if(P+1<N && S[P]=='&'&&S[P+1]=='&') P+=2;
    else break;
    int rt; char *r=not_(&rt);
    if(*oty!=TY_NUM || rt!=TY_NUM) die("and operands must be numbers");
    char *t=malloc(strlen(l)+strlen(r)+24); sprintf(t,"((%s)&&(%s))",l,r); free(l); free(r); l=t; *oty=TY_NUM;
  }
  return l;
}

static char *expr(int *oty){
  char *l=and_(oty);
  for(;;){
    skip();
    if(at("or")) P+=2;
    else if(P+1<N && S[P]=='|'&&S[P+1]=='|') P+=2;
    else break;
    int rt; char *r=and_(&rt);
    if(*oty!=TY_NUM || rt!=TY_NUM) die("or operands must be numbers");
    char *t=malloc(strlen(l)+strlen(r)+24); sprintf(t,"((%s)||(%s))",l,r); free(l); free(r); l=t; *oty=TY_NUM;
  }
  return l;
}

/* `for ch in p.name` / `for v in l.a.items`: a dotted source is walked here
 * instead of through primary(), because a struct field's type is only fixed
 * once a literal has been scanned. In an early pass an unresolved chain is
 * deferred (return -1), never a fatal error; the emit pass decides.
 *   >=0 : the resolved kind of the whole chain
 *    -1 : not decidable yet (base or link type still unknown)
 *    -2 : structurally wrong (base is not a struct, or the field does not exist)
 * The returned text is the C expression for the chain. */
static char *field_chain_source(int *okind){
  *okind=-1;
  char *base=parse_id();
  size_t cap=strlen(base)+96; char *text=malloc(cap); if(!text) die("allocation");
  strcpy(text,base);
  int vi=findv(base), si=-1, kind=-1, decided=1;
  if(vi<0) decided=0;                       /* base not seen yet: defer */
  else if(vt[vi]==TY_STRUCT) si=vs[vi];
  else { free(base); *okind=-2; return text; }   /* a number/string/list base */
  free(base);
  for(;;){
    skip();
    /* `..` is the range delimiter, never a field separator: `p.count..3` is a
     * numeric range whose lower bound is a field, and the range path owns it. */
    if(P>=N || S[P]!='.' || at("..")) break;
    P++; char *fld=parse_id(); skip();
    int ff=-1;
    if(si>=0) for(int f=0;f<SD[si].nf;f++) if(!strcmp(SD[si].fields[f],fld)){ ff=f; break; }
    if(si>=0 && ff<0){ free(fld); free(text); *okind=-2; return strdup(""); }
    size_t need=strlen(text)+strlen(fld)+2;
    if(need>cap){ cap=need+64; text=realloc(text,cap); if(!text) die("allocation"); }
    strcat(text,"."); strcat(text,fld);
    if(si<0 || ff<0){ decided=0; kind=-1; free(fld); continue; }
    if(SD[si].fty[ff]==FT_STRUCT){ int inner=SD[si].fsi[ff]; si=inner; kind=TY_STRUCT; }
    else if(SD[si].fset[ff]){
      /* read the field type BEFORE dropping si: `si=-1; kind=SD[si]...` would
       * index SD[-1], and the garbage there decides the loop's kind. */
      int ft=SD[si].fty[ff]; si=-1;
      kind=ft==FT_STR?TY_STR:(ft==FT_LIST?TY_LIST:TY_NUM);
    }
    else { decided=0; si=-1; kind=-1; }     /* field type not fixed yet */
    free(fld);
  }
  if(!decided){ *okind=-1; return text; }
  *okind=kind; return text;
}

/* Named sources are re-read each iteration, as on gen2. Literal, call and
 * field sources are evaluated once into a hidden reference before the loop. */
static char *for_header(char **source, int *kind, int *literal, char **end){
  P+=3;
  char *name=parse_id();
  static const char *reserved[]={"true","false","and","or","not","for","in",
    "hold","show","make","give","when","elif","else","otherwise","if",
    "while","break","continue","struct","use",NULL};
  for(int k=0;reserved[k];k++)
    if(!strcmp(name,reserved[k])) die("seed-min for binder cannot be a language keyword");
  skip(); eat("in"); skip();
  /* A parenthesised source is the source inside the parens: `for c in (s)`,
   * `for v in (p.items)`. The parens are unwrapped here, in every pass, so a
   * named/literal/call/field source inside them takes its normal path and is
   * still captured once per loop entry. A parenthesised RANGE is refused
   * below: `(0..3)` is not a collection. */
  int paren=0;
  if(P<N && S[P]=='('){
    /* Unwrap '('s that wrap the WHOLE source: the first '('s matching ')'
     * is the last token before '{' (`for c in ((s))`). A '(' whose match
     * closes earlier starts a parenthesised range BOUND --
     * `(lo + 1)..(hi * 2)` -- which is a number, not a collection, and
     * keeps the range path below. */
    size_t q=P; int dep=0, wraps=0;
    while(q<N){
      char c=S[q];
      if(c=='"'){ q++; while(q<N && S[q]!='"'){ if(S[q]=='\\' && q+1<N) q+=2; else q++; } if(q<N) q++; continue; }
      if(c=='/' && q+1<N && S[q+1]=='/'){ while(q<N && S[q]!='\n') q++; continue; }
      if(c=='(') dep++;
      else if(c==')'){ dep--; if(dep==0){ size_t z=q+1; while(z<N && (S[z]==' '||S[z]=='\t'||S[z]=='\r'||S[z]=='\n')) z++; wraps = z<N && S[z]=='{'; break; } }
      else if(c=='{' && dep==0) break;
      q++;
    }
    if(wraps){
      while(P<N && S[P]=='('){ paren++; P++; skip(); }
    }
  }
  *end=NULL;
  /* A field type is learned from literals in a later scan.  Do not freeze a
   * provisional string binder from an early pass when that field later proves
   * to be a list. */
  int deferred_field_kind=0;
  *literal=P<N && (S[P]=='"' || S[P]=='[');
  if(*literal){
    *source=atom(kind);
  } else {
    size_t start=P;
    int named=0;
    if(P<N && isid0(S[P])){
      char *candidate=parse_id(); skip();
      if(P<N && (S[P]=='{' || (paren && S[P]==')'))){
        int si=findv(candidate);
        if(si<0 || (vt[si]!=TY_LIST && vt[si]!=TY_STR)){
          if(in_fn && si<0)
            die("seed-min for source inside make must be a body local, literal, range or call: a body cannot capture top-level hold names");
          die("seed-min for source must be a list/string variable, literal or numeric range");
        }
        if(!strcmp(name,candidate)) die("seed-min for binder must differ from its source");
        *source=candidate; *kind=vt[si]; named=1;
      } else if(P<N && S[P]=='(' && strcmp(candidate,"len") && strcmp(candidate,"sx_len")){
        free(candidate); P=start; for_call++;
        *source=atom(kind); for_call--;
        if(*kind!=TY_STR && *kind!=TY_LIST) die("seed-min for call source must return a string or list");
        *literal=1; named=1; /* capture one result per loop entry */
      } else if(P<N && S[P]=='.'){
        /* a struct field (or a chain of them) naming a string/list */
        free(candidate); P=start;
        int fk; *source=field_chain_source(&fk);
        skip();
        if(at("..")){
          free(*source); *source=NULL; P=start;   /* a numeric range bound */
        } else {
          if(P<N && S[P]=='[')
            die("seed-min for field source cannot be indexed; hold the field in a variable first");
          if(fk==-1){
            if(types_final)
              die("seed-min for field source could not be resolved to a string or list field");
            fk=TY_STR;   /* provisional until the literal-type scan finishes */
            deferred_field_kind=1;
          } else if(fk==-2)
            die("seed-min for field source must name a field of a struct variable");
          else if(fk!=TY_STR && fk!=TY_LIST)
            die("seed-min for field source must be a string or list field, not a number or struct");
          *kind=fk; *literal=1; named=1; /* capture one field value per loop entry */
        }
      } else free(candidate);
    }
    if(!named){
      if(paren) die("seed-min for parenthesised source must be a list/string variable, literal, call or field inside the parens (a parenthesised range is not a collection)");
      P=start; range_bound=1;
      *source=expr(kind); skip();
      if(*kind!=TY_NUM) die("seed-min for range bounds must be numbers");
      if(!at("..")) die("seed-min for requires a numeric range, list/string variable or literal; checked call sources must return str/list");
      P+=2;
      int end_kind;
      *end=expr(&end_kind); range_bound=0;
      if(end_kind!=TY_NUM) die("seed-min for range bounds must be numbers");
    }
  }
  skip();
  for(int pi=0;pi<paren;pi++){
    if(P>=N || S[P]!=')') die("seed-min for parenthesised source needs a closing ) before {");
    P++; skip();
  }
  if(P>=N || S[P]!='{')
    die("seed-min for expected { after list/string source or numeric range");
  int ty=*kind==TY_STR?TY_STR:TY_NUM, vi=findv(name);
  if(vi>=0 && vt[vi]!=ty && !deferred_field_kind && !vdeferred[vi])
    die("seed-min for binder has an incompatible type");
  setv(name,ty);
  vdeferred[findv(name)]=deferred_field_kind;
  return name;
}

/* Consume one conditional tail consistently in both parser passes.
 * 0: no tail, 1: conditional branch, 2: final unconditional branch. */
static int conditional_tail(void){
  skip();
  if(at("elif")){ P+=4; return 1; }
  if(at("otherwise")) P+=9;
  else if(at("else")) P+=4;
  else return 0;
  skip();
  if(at("when")){ P+=4; return 1; }
  if(at("if")){ P+=2; return 1; }
  return 2;
}

/* Look ahead without consuming an expression or mistaking == for =. */
static int plain_assignment(void){
  size_t saved=P;
  if(P>=N || !isid0(S[P])) return 0;
  while(P<N && isid(S[P])) P++;
  skip();
  int yes=P<N && S[P]=='=' && (P+1>=N || S[P+1]!='=');
  P=saved; return yes;
}

static void end_local_scope(int saved_nv){
  if(producer_ret>=0) while(nv>saved_nv){ free(vn[--nv]); }
}
static void block(void){
  int saved_nv=nv;
  skip(); eat("{");
  for(;;){ skip(); if(P>=N) die("}"); if(S[P]=='}'){ P++; end_local_scope(saved_nv); return; } stmt(); }
}

static void skip_block(void){
  skip(); if(P>=N||S[P]!='{') die("{");
  int d=0;
  while(P<N){
    if(P+1<N && S[P]=='/' && S[P+1]=='/'){ while(P<N && S[P]!='\n') P++; continue; }
    if(S[P]=='"'){ P++; while(P<N&&S[P]!='"'){ if(S[P]=='\\'&&P+1<N)P+=2; else P++; } if(P<N)P++; continue; }
    if(S[P]=='{'){ d++; P++; continue; }
    if(S[P]=='}'){ d--; P++; if(d==0) return; continue; }
    P++;
  }
  die("} skip");
}

/* bare `push(NAME, EXPR)`: NAME must be a list variable.  Returns the value
 * text; *oname gets the list name.  Anything else is a clear error. */
static char *bare_push(char **oname){
  P+=4; skip();
  if(P>=N||S[P]!='(') die("push statement: expected push(list, value)");
  P++; skip();
  if(P>=N||!isid0(S[P])) die("push statement: the first argument must be a list variable name, e.g. push(xs, 4)");
  char *ln=parse_id(); skip();
  if(getty(ln)!=TY_LIST){
    char msg[256]; snprintf(msg,sizeof msg,"push statement: '%s' is not a list (hold %s = [] first)",ln,ln); die(msg);
  }
  if(P>=N||S[P]!=',') die("push statement: expected push(list, value)");
  P++;
  int vt_; char *v=expr(&vt_);
  if(vt_!=TY_NUM) die("push statement: list elements must be numbers");
  skip(); if(P>=N||S[P]!=')') die("push statement: expected ) after the value");
  P++;
  *oname=ln; return v;
}
/* a statement that is not hold/show/when/while/make/give/struct/push */
static void unknown_stmt(void){
  char w[64]; size_t i=0, q=P;
  while(q<N && isid(S[q]) && i+1<sizeof w) w[i++]=S[q++];
  w[i]=0;
  char msg[256];
  if(i) snprintf(msg,sizeof msg,"unknown statement '%s' (statements: hold show when while make give struct push(xs, v))",w);
  else snprintf(msg,sizeof msg,"unexpected character '%c' at the start of a statement",P<N?S[P]:'?');
  die(msg);
}

static void producer_statement(void){
  if(producer_ret>=0 && !(at("hold") || at("show") || at("give") || at("push") ||
      at("when") || at("while") || at("for") || at("break") || at("continue") || plain_assignment()))
    die("seed-min unsupported statement in typed function");
}
static void stmt(void){
  skip(); if(P>=N||S[P]=='}') return;
  producer_statement();
  if(at("struct")){
    /* skip_struct_decl also eats a template's type parameter list */
    P+=6; skip_struct_decl();
    return;
  }
  if(at("make")){
    if(in_fn) die("nested make");
    Fn f=function_header(); free_header(&f);
    skip_block();
    return;
  }
  if(at("give")){
    P+=4; skip(); int ty; char *e=expr(&ty);
    if(in_fn && ty!=function_ret) die("seed-min function give type does not match declared return type");
    if(producer_ret==TY_STR) printf("  return sx_sb_from(%s);\n",e);
    else printf("  return %s;\n", e);
    free(e); return;
  }
  if(at("hold") || plain_assignment()){
    int is_hold=at("hold");
    if(is_hold) P+=4;
    char *n=parse_id(); int i=findv(n);
    int annotation=is_hold?hold_annotation():-1;
    if(!is_hold && i<0) die("assignment needs a declared variable (use hold first)");
    skip(); eat("="); int ty; char *e=expr(&ty);
    check_hold_type(n,annotation,ty,last_si);
    if(producer_ret>=0 && i>=0 && vt[i]!=ty) die("seed-min producer local type cannot change");
    if(!is_hold && (vt[i]!=ty || ty==TY_STRUCT))
      die("assignment type mismatch (struct assignment is not supported by seed-min)");
    if(i<0){
      if(ty==TY_STRUCT){
        register_local(n, ty, e);
        int si=getsi(n);
        if(si>=0) printf("  %s %s = %s;\n", SD[si].name, n, e);
        else printf("  /* struct */ %s = %s;\n", n, e);
      } else {
        setv(n,ty);
        if(ty==TY_STR){
          if(producer_ret>=0) printf("  char *%s = sx_sb_from(%s);\n",n,e);
          else printf("  char *%s = %s;\n", n, e);
        }
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
        /* A prefix on a variable name says nothing about ownership. Only
         * these actual runtime calls return a fresh owning builder. */
        int need_copy = strncmp(e,"sx_cat(",7) && strncmp(e,"sx_chr(",7) &&
          strncmp(e,"sx_arg(",7) && strncmp(e,"sx_read(",8) && strncmp(e,"sx_http(",8);
        printf("  { char *_sx_iter_value = %s%s%s; sx_sb_free(%s); %s = _sx_iter_value; }\n",
               need_copy?"sx_sb_from(":"", e, need_copy?")":"", n, n);
      } else printf("  %s = %s;\n", n, e);
    }
    if(annotation>=0){
      int ai=findv(n); vdecl[ai]=annotation;
      vdecls[ai]=annotation==TY_STRUCT?annotation_si:-1;
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
    P+=4; int ty; char *c=expr(&ty); if(producer_ret>=0 && ty!=TY_NUM) die("seed-min typed function condition must be numeric"); printf("  if(%s) {\n", c); free(c); block();
    int tail;
    while((tail=conditional_tail())){
      if(tail==2){ printf("  } else {\n"); block(); break; }
      c=expr(&ty); if(producer_ret>=0 && ty!=TY_NUM) die("seed-min typed function condition must be numeric"); printf("  } else if(%s) {\n",c); free(c); block();
    }
    printf("  }\n"); return;
  }
  if(at("for")){
    int before=nv;
    char *source, *end; int kind, literal; char *name=for_header(&source,&kind,&literal,&end);
    /* Inside any make body the binder is a C local of that body: declare it
     * once here (a later loop reusing the name finds it already in scope). At
     * top level decls() has already emitted it, so nothing is printed. */
    if(in_fn && findv(name)>=before){
      if(kind==TY_STR) printf("  char *%s = sx_sb_new(1);\n",name);
      else printf("  double %s = 0;\n",name);
    }
    if(end){
      /* Gen2 uses the binder as the counter: start once, upper bound each
       * condition check, increment even on continue; break skips increment. */
      printf("  for(%s = %s; %s < %s; %s = %s + 1.0) {\n",name,source,name,end,name,name);
      loop_depth++; block(); loop_depth--; printf("  }\n");
      free(name); free(source); free(end); return;
    }
    unsigned id=for_serial++;
    if(literal){
      char temp[64]; snprintf(temp,sizeof temp,"_sx_iter_src_%u",id);
      printf("  { %s *%s = %s;\n",kind==TY_STR?"char":"sx_list",temp,source);
      free(source); source=strdup(temp);
    }
    printf("  for(double _sx_iter_%u=0; _sx_iter_%u < %s(%s); _sx_iter_%u++) {\n",
      id,id,kind==TY_STR?"sx_len":"sx_llen",source,id);
    if(kind==TY_STR) printf("  %s = sx_chr(sx_idx(%s,_sx_iter_%u));\n",name,source,id);
    else printf("  %s = sx_lget(%s,_sx_iter_%u);\n",name,source,id);
    loop_depth++; block(); loop_depth--; printf("  }\n");
    if(literal) printf("  }\n");
    free(name); free(source); free(end); return;
  }
  if(at("while")){
    P+=5; int ty; char *c=expr(&ty); if(producer_ret>=0 && ty!=TY_NUM) die("seed-min typed function condition must be numeric"); printf("  while(%s) {\n", c); free(c); loop_depth++; block(); loop_depth--; printf("  }\n"); return;
  }
  if(at("break") || at("continue")){
    int br=at("break");
    if(!loop_depth) die("break/continue requires an enclosing loop");
    P+=br?5:8; printf("  %s;\n",br?"break":"continue"); return;
  }
  if(at("push")){
    /* bare `push(xs, v)` statement == `hold xs = push(xs, v)` */
    char *ln; char *v=bare_push(&ln);
    printf("  %s = sx_lpush(%s,(double)(%s));\n", ln, ln, v);
    free(ln); free(v); return;
  }
  unknown_stmt();
}

/* Borrow read-only string parameters. A writable parameter still gets its
 * own entry copy: assignment can free it, so sharing that buffer with either
 * the caller or another argument would be a use-after-free. This deliberately
 * conservative lexical check recognizes hold/plain assignment, annotations,
 * and for binders at any depth. Comments and quoted strings are not code.
 * It is NOT a collector: locals/returns/temporaries retain the old lifetime.
 * Keep this in sync with any new string-binding syntax in stmt/for_header. */
static int parameter_may_write(const char *p, const char *end, const char *name){
  size_t n=strlen(name);
  while(p<end && *p){
    rf_space(&p);
    if(p>=end || !*p) break;
    if(*p=='"'){
      p++;
      while(p<end && *p && *p!='"'){
        if(*p=='\\' && p+1<end) p++;
        p++;
      }
      if(p<end && *p) p++;
    } else if(isid0(*p)){
      const char *start=p;
      while(p<end && isid(*p)) p++;
      if((size_t)(p-start)==n && !memcmp(start,name,n)){
        const char *q=p; rf_space(&q);
        if(*q=='=' || *q==':' ||
           (strchr("+-*/%",*q) && *q && q[1]=='=') ||
           (!strncmp(q,"in",2) && !isid(q[2]))) return 1;
      }
    } else p++;
  }
  return 0;
}

static void emit_one_fn(void){
  Fn f=function_header();
  /* A parameter of a legacy untyped make may not silently take over the slot
   * of an annotated top-level hold: check against the enclosing table before
   * the body scope replaces it. Fully typed producers have an isolated scope
   * by design, so shadowing an annotated global is allowed there. */
  if(!f.annotated) for(int i=0;i<f.np;i++){
    int vi=findv(f.params[i]);
    if(vi>=0 && vdecl[vi]>=0) die("seed-min parameter cannot shadow an annotated global");
  }
  printf("static %s%s(",ctype(f.ret),f.name);
  if(!f.np) printf("void");
  for(int i=0;i<f.np;i++) printf("%s%s%s",i?", ":"",ctype(f.pt[i]),f.params[i]);
  printf("){\n");
  const char *flow_at=S+P;
  int returns=rf_block(&flow_at,0);
  Env *env=f.annotated?enter_producer(f.ret):enter_scope();
  for(int i=0;i<f.np;i++){
    setv(f.params[i],f.pt[i]);
    if(f.annotated){
      vdecl[findv(f.params[i])]=f.pt[i];
      /* String arguments are borrowed. Copy before a local reassignment can
       * free them; aliased arguments must not invalidate each other/caller. */
      if(f.pt[i]==TY_STR && parameter_may_write(S+P,flow_at,f.params[i]))
        printf("  %s = sx_sb_from(%s);\n",f.params[i],f.params[i]);
    }
  }
  in_fn=1; function_ret=f.ret; skip();
  eat("{");
  for(;;){
    skip(); if(P>=N) die("}"); if(S[P]=='}'){ P++; break; }
    stmt();
  }
  in_fn=0; function_ret=-1;
  if(f.annotated){
    if(!returns) die("seed-min typed function may fall through without give");
    leave_producer(env);
  } else {
    printf("  return 0;\n");
    leave_scope(env);
  }
  printf("}\n\n"); free_header(&f);
}

static void scan_function_headers(void){
  size_t saved=P; P=0; int depth=0;
  while(P<N){
    skip(); if(P>=N) break;
    if(at("make")){
      if(depth) die("seed-min make must be at top level");
      Fn f=function_header();
      if(nfunctions>=512) die("seed-min function limit is 512");
      if(findfn(f.name)>=0) die("seed-min duplicate function name");
      skip(); size_t start=P; skip_block();
      if(f.ntp){ f.body=strndup(S+start,P-start); templates++; }
      functions[nfunctions++]=f; continue;
    }
    if(S[P]=='"'){
      P++; while(P<N && S[P]!='"'){ if(S[P]=='\\' && P+1<N) P+=2; else P++; }
      if(P<N) P++; continue;
    }
    if(S[P]=='{') depth++;
    if(S[P]=='}') depth--;
    P++;
  }
  P=saved;
}
static void function_prototypes(void){
  for(int i=0;i<nfunctions;i++){
    Fn *f=&functions[i]; if(f->ntp) continue; printf("static %s%s(",ctype(f->ret),f->name);
    if(!f->np) printf("void");
    for(int j=0;j<f->np;j++) printf("%s%s",j?",":"",ctype(f->pt[j]));
    printf(");\n");
  }
}

static void emit_all_fns(void){
  size_t save=P;
  while(P<N){
    skip(); if(P>=N) break;
    if(at("make")){
      size_t start=P; Fn f=function_header(); int generic=f.ntp; free_header(&f);
      if(generic) skip_block(); else { P=start; emit_one_fn(); }
      continue;
    }
    if(at("struct")){ P+=6; skip_struct_decl(); continue; }
    if(S[P]=='"'){ P++; while(P<N&&S[P]!='"'){ if(S[P]=='\\'&&P+1<N)P+=2; else P++; } if(P<N)P++; continue; }
    P++;
  }
  P=save;
}

static void emit_typedefs(void){
  for(int i=0;i<nsd;i++){
    printf("typedef struct {");
    for(int f=0;f<SD[i].nf;f++){
      if(SD[i].fty[f]==FT_STRUCT) printf(" %s %s;", SD[SD[i].fsi[f]].name, SD[i].fields[f]);
      else if(SD[i].fty[f]==FT_LIST) printf(" sx_list *%s;", SD[i].fields[f]);
      else if(SD[i].fty[f]==FT_STR) printf(" char *%s;", SD[i].fields[f]);
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
      if(SD[si].fty[f]==FT_STRUCT) return SD[si].fsi[f];
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
      if(SD[si].fty[f]==FT_STRUCT){ if(osi) *osi=SD[si].fsi[f]; return TY_STRUCT; }
      if(SD[si].fty[f]==FT_LIST) return TY_LIST;
      return SD[si].fty[f]==FT_STR ? TY_STR : TY_NUM;
    }
  return TY_NUM;
}

static void preamble(void){
  puts("#include <stdio.h>"); puts("#include <stdlib.h>"); puts("#include <string.h>"); puts("#include <stdarg.h>"); puts("#include <stdint.h>"); puts("#include <stddef.h>");
  puts("typedef struct { double *d; long n; long cap; } sx_list;");
  puts("static double sx_mod(double a,double b){ long x=(long)a, y=(long)b; if(!y){fputs(\"division by zero\\n\",stderr);exit(1);} return (double)(x%y); }");
  puts("static sx_list *sx_llit(int n,...){ sx_list *L=malloc(sizeof*L); L->n=n; L->cap=n<4?4:n; L->d=malloc(sizeof(double)*(size_t)L->cap); va_list ap; va_start(ap,n); for(int i=0;i<n;i++) L->d[i]=va_arg(ap,double); va_end(ap); return L; }");
  puts("static double sx_lget(sx_list *L,double v){ long i=(long)v; if(!L){fputs(\"sx: null list\\n\",stderr);exit(1);} if(i<0)i+=L->n; if(i<0||i>=L->n){fputs(\"sx: list index\\n\",stderr);exit(1);} return L->d[i]; }");
  puts("static double sx_llen(sx_list *L){ return L?(double)L->n:0.0; }");
  puts("static sx_list *sx_lpush(sx_list *L,double v){ if(!L){L=malloc(sizeof*L); L->n=0; L->cap=4; L->d=malloc(sizeof(double)*4);} if(L->n>=L->cap){ L->cap*=2; L->d=realloc(L->d,sizeof(double)*(size_t)L->cap);} L->d[L->n++]=v; return L; }");
  /* Names were chosen absent from the entire expanded source. The seed
   * runtime is single-threaded/uncollected; builder nodes themselves are
   * freed on completion. The returned list retains ordinary seed ownership. */
  printf("typedef struct %s_node { sx_list *list; struct %s_node *prev; } %s_node;\n",list_seq_prefix,list_seq_prefix,list_seq_prefix);
  printf("static %s_node *%s_top;\n",list_seq_prefix,list_seq_prefix);
  printf("static void %s_begin(int n){ %s_node *q=malloc(sizeof *q); if(!q) exit(1); q->list=malloc(sizeof *q->list); if(!q->list) exit(1); q->list->n=0; q->list->cap=n<4?4:n; q->list->d=malloc(sizeof(double)*(size_t)q->list->cap); if(!q->list->d) exit(1); q->prev=%s_top; %s_top=q; }\n",list_seq_prefix,list_seq_prefix,list_seq_prefix,list_seq_prefix);
  printf("static void %s_add(double v){ %s_top->list->d[%s_top->list->n++]=v; }\n",list_seq_prefix,list_seq_prefix,list_seq_prefix);
  printf("static sx_list *%s_end(void){ %s_node *q=%s_top; sx_list *v=q->list; %s_top=q->prev; free(q); return v; }\n",list_seq_prefix,list_seq_prefix,list_seq_prefix,list_seq_prefix);
  puts("/* ----- registered string builder -------------------------------------\n * Strings returned by sx_cat/sx_chr/sx_sb_from carry a hidden sx_sb header\n * with current length and capacity. Each concat() result is\n * backed by fresh allocations, NOT in-place O(1) append. String literals and\n * foreign C strings do NOT have a header -- the registry detects that and copies\n * them into a fresh builder on first use. ---------------------------- */");
  puts("#include <stddef.h>");
  puts("typedef struct sx_sb { size_t len, cap; struct sx_sb *next; char data[1]; } sx_sb;");
  puts("/* Exact allocation registry: never inspect bytes before a foreign pointer. */");
  puts("static sx_sb **sx_sb_buckets; static size_t sx_sb_nbucket, sx_sb_count;");
  puts("static size_t sx_sb_hash(const void *p){ uintptr_t v=(uintptr_t)p; return (size_t)((v>>3)^(v>>17)); }");
  puts("static sx_sb *sx_sb_hdr(const char *p){ return (sx_sb*)((char*)p - offsetof(sx_sb,data)); }");
  puts("static int sx_sb_is(const char *p){");
  puts("  if(!p || !sx_sb_nbucket) return 0;");
  puts("  for(sx_sb *h=sx_sb_buckets[sx_sb_hash(p)&(sx_sb_nbucket-1)]; h; h=h->next) if(h->data==p) return 1;");
  puts("  return 0; }");
  puts("static void sx_sb_register(sx_sb *h){");
  puts("  if(sx_sb_count>=sx_sb_nbucket){");
  puts("    size_t n=sx_sb_nbucket?sx_sb_nbucket*2:1024;");
  puts("    if(n<sx_sb_nbucket || n>SIZE_MAX/sizeof(sx_sb*)){fputs(\"sx: out of memory\\n\",stderr);exit(1);}");
  puts("    sx_sb **b=calloc(n,sizeof *b); if(!b){fputs(\"sx: out of memory\\n\",stderr);exit(1);}");
  puts("    for(size_t i=0;i<sx_sb_nbucket;i++){ sx_sb *p=sx_sb_buckets[i]; while(p){sx_sb *next=p->next; size_t j=sx_sb_hash(p->data)&(n-1); p->next=b[j]; b[j]=p; p=next;} }");
  puts("    free(sx_sb_buckets); sx_sb_buckets=b; sx_sb_nbucket=n;");
  puts("  }");
  puts("  size_t i=sx_sb_hash(h->data)&(sx_sb_nbucket-1); h->next=sx_sb_buckets[i]; sx_sb_buckets[i]=h; sx_sb_count++;");
  puts("}");
  puts("/* ----- conservative mark & sweep over the builder registry -------------");
  puts(" * Roots are the C stack, nothing else. Every Sayanox variable this compiler");
  puts(" * emits is a local of sx_prog, parameters and temporaries are C locals, and");
  puts(" * no heap object in this runtime stores a string pointer (lists hold");
  puts(" * doubles), so scanning from the anchor planted in main down to the");
  puts(" * collector's own frame reaches every builder a running program can still");
  puts(" * name. Interior pointers count: a candidate word is matched against the");
  puts(" * whole block by binary search, so a cursor into the middle of a string");
  puts(" * keeps it alive. The explicit sx_sb_free on reassignment stays -- it");
  puts(" * reclaims the common case immediately, and the collector only has to find");
  puts(" * what the assignment wrapper cannot see: dropped temporaries and results.");
  puts(" * Nothing here moves an object, so a borrowed pointer stays valid. */");
  puts("#include <setjmp.h>");
  puts("#if defined(__SANITIZE_ADDRESS__)");
  puts("#define SX_GC_SCAN __attribute__((no_sanitize_address))");
  puts("#elif defined(__has_feature)");
  puts("#if __has_feature(address_sanitizer)");
  puts("#define SX_GC_SCAN __attribute__((no_sanitize_address))");
  puts("#endif");
  puts("#endif");
  puts("#ifndef SX_GC_SCAN");
  puts("#define SX_GC_SCAN   /* reading other frames is not an error, it is the point */");
  puts("#endif");
  puts("static char *sx_gc_bot;                 /* stack anchor, planted by main */");
  puts("static size_t sx_gc_bytes;              /* bytes held by registered builders */");
  puts("static size_t sx_gc_thresh = 8388608;   /* collect once live bytes pass this */");
  puts("static double sx_gc_n, sx_gc_freed;     /* collections run, bytes last freed */");
  puts("static sx_sb **sx_gc_arr; static unsigned char *sx_gc_bits; static size_t sx_gc_cap;");
  puts("static void sx_gc_init(void *bot){ sx_gc_bot=(char*)bot; }");
  puts("static size_t sx_gc_block(sx_sb *h){ return offsetof(sx_sb,data)+h->cap+1; }");
  puts("static int sx_gc_cmp(const void *a,const void *b){");
  puts("  sx_sb *x=*(sx_sb *const *)a, *y=*(sx_sb *const *)b;");
  puts("  return x<y ? -1 : (x>y ? 1 : 0); }");
  puts("static void sx_gc_grow(void){ sx_gc_thresh=sx_gc_bytes+sx_gc_bytes/2+8388608; }");
  puts("static SX_GC_SCAN void sx_gc_roots(char *lo,char *hi,size_t k){");
  puts("  while((uintptr_t)lo % sizeof(char*)) lo++;");
  puts("  for(; lo+sizeof(char*)<=hi; lo+=sizeof(char*)){");
  puts("    char *c=*(char**)lo; size_t a=0, b=k;");
  puts("    if(!c) continue;");
  puts("    while(a<b){ size_t m=a+(b-a)/2; if((char*)sx_gc_arr[m]<=c) a=m+1; else b=m; }");
  puts("    if(a && c<=sx_gc_arr[a-1]->data+sx_gc_arr[a-1]->cap) sx_gc_bits[a-1]=1;");
  puts("  }");
  puts("}");
  puts("static void sx_gc_collect(void){");
  puts("  size_t n=sx_sb_count, k=0, i, live=0, freed=0;");
  puts("  if(!sx_gc_bot) return;                /* no anchor yet: nothing is rooted */");
  puts("  if(n>sx_gc_cap){");
  puts("    sx_sb **a; unsigned char *b;");
  puts("    a=(sx_sb**)realloc(sx_gc_arr,n*sizeof *a);");
  puts("    if(!a){ sx_gc_grow(); return; }     /* no room to collect: carry on */");
  puts("    sx_gc_arr=a;");
  puts("    b=(unsigned char*)realloc(sx_gc_bits,n);");
  puts("    if(!b){ sx_gc_grow(); return; }");
  puts("    sx_gc_bits=b; sx_gc_cap=n;");
  puts("  }");
  puts("  for(i=0;i<sx_sb_nbucket;i++){ sx_sb *h=sx_sb_buckets[i]; while(h){ if(k<n) sx_gc_arr[k++]=h; h=h->next; } }");
  puts("  qsort(sx_gc_arr,k,sizeof *sx_gc_arr,sx_gc_cmp);");
  puts("  memset(sx_gc_bits,0,k);");
  puts("  { jmp_buf jb; char *lo, *hi;");
  puts("    setjmp(jb);                         /* spill the registers onto the stack */");
  puts("    lo=(char*)&jb; hi=sx_gc_bot;");
  puts("    if(lo>hi){ char *t=lo; lo=hi; hi=t; }");
  puts("    sx_gc_roots(lo,hi,k);");
  puts("  }");
  puts("  for(i=0;i<sx_sb_nbucket;i++) sx_sb_buckets[i]=0;");
  puts("  for(i=0;i<k;i++){");
  puts("    sx_sb *h=sx_gc_arr[i];");
  puts("    if(sx_gc_bits[i]){ size_t j=sx_sb_hash(h->data)&(sx_sb_nbucket-1); h->next=sx_sb_buckets[j]; sx_sb_buckets[j]=h; live++; }");
  puts("    else { freed+=sx_gc_block(h); free(h); }");
  puts("  }");
  puts("  sx_sb_count=live;");
  puts("  sx_gc_bytes = freed<sx_gc_bytes ? sx_gc_bytes-freed : 0;");
  puts("  sx_gc_freed=(double)freed; sx_gc_n+=1;");
  puts("  sx_gc_grow();");
  puts("}");
  puts("static double sx_gc_run(void){ sx_gc_collect(); return sx_gc_freed; }");
  puts("static double sx_gc_live(void){ return (double)sx_gc_bytes; }");
  puts("static double sx_gc_count(void){ return sx_gc_n; }");
  puts("static char *sx_sb_new(size_t cap){");
  puts("  if(cap<32) cap=32;");
  puts("  if(cap>SIZE_MAX - offsetof(sx_sb,data) - 1){fputs(\"sx: out of memory\\n\",stderr);exit(1);}");
  puts("  size_t need=offsetof(sx_sb,data)+cap+1;");
  puts("  if(sx_gc_bytes+need>sx_gc_thresh) sx_gc_collect();");
  puts("  sx_sb *h=(sx_sb*)malloc(need);");
  puts("  if(!h){ sx_gc_collect(); h=(sx_sb*)malloc(need); }   /* collect before giving up */");
  puts("  if(!h){fputs(\"sx: out of memory\\n\",stderr);exit(1);}");
  puts("  h->len=0; h->cap=cap; h->data[0]=0; sx_sb_register(h); sx_gc_bytes+=need; return h->data; }");
  puts("static char *sx_sb_from(const char *s){ size_t n=strlen(s?s:\"\");");
  puts("  size_t cap=n<32?32:n; char *r=sx_sb_new(cap); if(n)memcpy(r,s,n); r[n]=0; sx_sb_hdr(r)->len=n; return r; }");
  puts("static void sx_sb_free(const char *p){");
  puts("  if(!p || !sx_sb_nbucket) return;");
  puts("  sx_sb **link=&sx_sb_buckets[sx_sb_hash(p)&(sx_sb_nbucket-1)];");
  puts("  while(*link){ sx_sb *h=*link; if(h->data==p){ size_t z=sx_gc_block(h); *link=h->next; sx_sb_count--;");
  puts("    sx_gc_bytes = z<sx_gc_bytes ? sx_gc_bytes-z : 0; free(h); return;} link=&h->next; }");
  puts("}");
  puts("static char *sx_sb_app(const char *a,const char *b){");
  puts("  const char *aa=a?a:\"\"; const char *bb=b?b:\"\";");
  puts("  int ia=sx_sb_is(aa);");
  puts("  size_t la=ia?sx_sb_hdr(aa)->len:strlen(aa);");
  puts("  size_t lb=strlen(bb);");
  puts("  size_t need=la+lb;");
  puts("  /* IMPORTANT: sx_sb_app NEVER frees `a` or `b`. Old `a` is always freed");
  puts("   * by the assignment wrapper:  { char *_v = sx_cat(a,b); sx_sb_free(a); a=_v; }");
  puts("   * which evaluates RHS to a temp first, then frees the old LHS. This");
  puts("   * eliminates all double-free / use-after-free hazards from aliased vars");
  puts("   * (the LHS may currently point at another variable like `q`, and freeing");
  puts("   * it here would invalidate q for later use). Starting from a's existing");
  puts("   * cap preserves spare capacity, but each concat still copies its bytes. */");
  puts("  size_t cap=ia?sx_sb_hdr(aa)->cap:32; while(cap<need+1)cap*=2;");
  puts("  char *r=sx_sb_new(cap); sx_sb *h=sx_sb_hdr(r);");
  puts("  if(la)memcpy(r,aa,la); memcpy(r+la,bb,lb); r[need]=0; h->len=need;");
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
  puts("#include <time.h>");
  puts("static struct timespec sx_http_last; static int sx_http_seen=0;");
  puts("static char *sx_http(const char *u){ size_t L=strlen(u); if(L>3000) return sx_sb_new(1); if(strncmp(u,\"http://\",7)&&strncmp(u,\"https://\",8)) return sx_sb_new(1); for(size_t i=0;i<L;i++){ unsigned char c=(unsigned char)u[i]; int ok=(c>=97&&c<=122)||(c>=65&&c<=90)||(c>=48&&c<=57)||(c!=0&&strchr(\"-._~:/?&=%+#@,;\",c)); if(!ok) return sx_sb_new(1); } if(sx_http_seen){ struct timespec now; clock_gettime(CLOCK_MONOTONIC,&now); double el=(double)(now.tv_sec-sx_http_last.tv_sec)+(double)(now.tv_nsec-sx_http_last.tv_nsec)/1e9; if(el<1.0){ struct timespec w; w.tv_sec=0; w.tv_nsec=(long)((1.0-el)*1e9); nanosleep(&w,NULL); } } sx_http_seen=1; clock_gettime(CLOCK_MONOTONIC,&sx_http_last); char cmd[4096]; snprintf(cmd,sizeof cmd,\"curl -sS -f -m 10 --max-filesize 1000000 -A sayanox-http/0.1 '%s' 2>/dev/null\",u); FILE *p=popen(cmd,\"r\"); if(!p) return sx_sb_new(1); char *b=malloc(1000001); size_t rd=fread(b,1,1000000,p); b[rd]=0; pclose(p); char *r=sx_sb_from(b); free(b); return r; }");
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
  for(int i=0;i<2048;i++){ vdecl[i]=-1; vdecls[i]=-1; vdeferred[i]=0; }
  while(P<N){
    skip(); if(P>=N) break;
    if(at("struct")){ P+=6; skip_struct_decl(); continue; }
    if(at("make")){
      Fn f=function_header(); free_header(&f);
      skip_block(); continue;
    }
    if(at("for")){
      char *source, *end; int kind, literal; char *name=for_header(&source,&kind,&literal,&end);
      free(name); free(source); free(end); continue;
    }
    if(at("hold")){
      P+=4; char *id=parse_id(); int annotation=hold_annotation(); skip(); if(at("=")){ P++; skip();
        int ty=TY_NUM; int si=-1;
        if(P<N && S[P]=='"') ty=TY_STR;
        else if(P<N && S[P]=='[') ty=TY_LIST;
        else if(at("concat")||at("chr")||at("read_file")||at("http_get")||at("arg")||at("sx_cat")||at("sx_chr")||at("sx_read")||at("sx_arg")) ty=TY_STR;
        else if(at("push")) ty=TY_LIST;
        else if(P<N && isid0(S[P])){
          size_t rhs_start=P; char *t=parse_id();
          si=find_struct(t);
          if(si>=0) ty=TY_STRUCT;
          else if(P<N && S[P]=='<' && find_gstruct(t)>=0){
            /* A generic instantiation on the right of hold: `hold b =
               Box<num> { 7 }` declares b as the mangled struct `Box__n`,
               exactly as a concrete literal declares its name. Creating the
               instantiation here is idempotent, so the four collect/scan
               rounds agree on the struct index. */
            int gk[8], gks[8];
            si=instantiate_gstruct(find_gstruct(t),gk,gks);
            ty=TY_STRUCT;
          }
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
                  if(SD[cur].fty[ff]==FT_STRUCT){ ty=TY_STRUCT; si=SD[cur].fsi[ff]; }
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
                  else ty=SD[cur].fty[ff]==FT_STR?TY_STR:(SD[cur].fty[ff]==FT_LIST?TY_LIST:TY_NUM);
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
          int fi=findfn(t);
          skip();
          if(fi>=0 && P<N && S[P]=='('){
            if(functions[fi].ntp){ P=rhs_start; char *e=expr(&ty); free(e); }
            else ty=functions[fi].ret;
            si=-1;
          }
          free(t);
        }
        int vi=findv(id), declared=vi<0?-1:vdecl[vi];
        if(annotation>=0 && declared>=0 && annotation!=declared)
          die("conflicting hold type annotation");
        if(annotation>=0) declared=annotation;
        if(declared>=0){
          if(declared==TY_STRUCT){
            int want=annotation==TY_STRUCT?annotation_si:(vi<0?-1:vdecls[vi]);
            if(ty!=TY_STRUCT || (si>=0 && want>=0 && si!=want)){
              char msg[256];
              snprintf(msg,sizeof msg,"hold '%s': initializer/assignment is not the declared struct %s",id,
                       want>=0?SD[want].name:"<unknown>");
              die(msg);
            }
            if(want<0) die("seed-min internal: missing struct hold annotation");
            setv_struct(id,want); vdecl[findv(id)]=TY_STRUCT; vdecls[findv(id)]=want;
          } else {
            setv(id,declared); vdecl[findv(id)]=declared; vdecls[findv(id)]=-1;
          }
        } else if(ty==TY_STRUCT && si>=0) setv_struct(id, si);
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
  int saved_nv=nv;
  skip(); eat("{");
  for(;;){ skip(); if(P>=N) die("}"); if(S[P]=='}'){ P++; end_local_scope(saved_nv); return; } scan_stmt(); }
}
static void scan_stmt(void){
  skip(); if(P>=N||S[P]=='}') return;
  producer_statement();
  if(at("struct")){ P+=6; skip_struct_decl(); return; }
  if(at("make")){
    Fn f=function_header();
    if(f.ntp){ free_header(&f); skip_block(); return; }
    Env *env=f.annotated?enter_producer(f.ret):enter_scope();
    for(int i=0;i<f.np;i++){
      setv(f.params[i],f.pt[i]);
      if(f.annotated) vdecl[findv(f.params[i])]=f.pt[i];
    }
    in_fn=1; scan_body(); in_fn=0;
    if(f.annotated) leave_producer(env); else leave_scope(env);
    free_header(&f); return;
  }
  if(at("give")){
    P+=4; int ty; char *e=expr(&ty);
    if(producer_ret>=0 && ty!=producer_ret) die("seed-min producer give type does not match declared return type");
    free(e); return;
  }
  if(at("hold") || plain_assignment()){
    int is_hold=at("hold");
    if(is_hold) P+=4;
    char *n=parse_id(); int annotation=is_hold?hold_annotation():-1;
    skip(); eat("="); int ty; char *e=expr(&ty);
    if(!in_fn || producer_ret>=0) check_hold_type(n,annotation,ty,last_si);
    if(in_fn){
      int vi=findv(n);
      if(producer_ret>=0){
        if(ty==TY_STRUCT) die("seed-min typed producers cannot hold structs");
        if(!is_hold && vi<0) die("seed-min producer assignment needs a declared local");
        if(vi>=0 && vt[vi]!=ty) die("seed-min producer local type cannot change");
        setv(n,ty);
      } else {
        /* legacy untyped body: the name is a C local of that body, so the
         * scan pass has to know it (a later `for v in xs` or `xs[0]` in the
         * same body is checked against it) */
        if(!is_hold && vi<0) die("assignment needs a declared variable (use hold first)");
        register_local(n,ty,e);
      }
      if(annotation>=0){
      int ai=findv(n); vdecl[ai]=annotation;
      vdecls[ai]=annotation==TY_STRUCT?annotation_si:-1;
    }
    }
    free(e); free(n); return;
  }
  if(at("show")){ P+=4; int ty; char *e=expr(&ty); free(e); return; }
  if(at("when")){
    P+=4; int ty; char *c=expr(&ty); if(producer_ret>=0 && ty!=TY_NUM) die("seed-min typed function condition must be numeric"); free(c); scan_body(); skip();
    int tail;
    while((tail=conditional_tail())){
      if(tail==2){ scan_body(); break; }
      c=expr(&ty); if(producer_ret>=0 && ty!=TY_NUM) die("seed-min typed function condition must be numeric"); free(c); scan_body();
    }
    return;
  }
  if(at("for")){
    char *source, *end; int kind, literal; char *name=for_header(&source,&kind,&literal,&end);
    loop_depth++; scan_body(); loop_depth--;
    free(name); free(source); free(end); return;
  }
  if(at("while")){ P+=5; int ty; char *c=expr(&ty); if(producer_ret>=0 && ty!=TY_NUM) die("seed-min typed function condition must be numeric"); free(c); loop_depth++; scan_body(); loop_depth--; return; }
  if(at("break") || at("continue")){
    if(!loop_depth) die("break/continue requires an enclosing loop");
    P+=at("break")?5:8; return;
  }
  if(at("push")){
    if(templates && (!in_fn || producer_ret>=0)){
      char *name, *value=bare_push(&name); free(name); free(value); return;
    }
    /* types may not be known yet in this pass: just skip the call */
    P+=4; skip(); if(P>=N||S[P]!='(') die("push statement: expected push(list, value)");
    int d=0;
    while(P<N){
      if(S[P]=='"'){ P++; while(P<N&&S[P]!='"'){ if(S[P]=='\\'&&P+1<N)P+=2; else P++; } if(P<N)P++; continue; }
      if(S[P]=='(') d++; else if(S[P]==')'){ d--; if(d==0){ P++; break; } }
      P++;
    }
    return;
  }
  unknown_stmt();
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
    N=strlen(S); user_source_size=N;
  }
  list_seq_prefix=strdup("_sx_seed_seq");
  while(strstr(S,list_seq_prefix)){
    size_t z=strlen(list_seq_prefix);
    char *next=realloc(list_seq_prefix,z+2); if(!next) die("list prefix allocation");
    list_seq_prefix=next; list_seq_prefix[z]='x'; list_seq_prefix[z+1]=0;
  }
  P=0;
  scan_function_headers();
  scan_structs();
  /* struct field types come from literals, and literal values can name
   * variables whose type is only known after collect(); alternate both
   * until they are stable (4 rounds, same as the original collect budget) */
  for(int pass=0;pass<4;pass++){ collect(); scan_literals(); }
  generic_finalized=1; types_final=1;
  P=0; preamble(); function_prototypes(); emit_all_fns();
  /* The program body is its own function so that main's frame -- which holds
   * the collector's stack anchor -- always sits above every Sayanox variable;
   * the volatile function pointer keeps the call indirect, so the body cannot
   * be inlined back into main and lose that ordering. */
  puts("static int sx_prog(void){");
  decls(); P=0;
  while(P<N){ skip(); if(P>=N) break; stmt(); }
  puts("  return 0;\n}");
  puts("int main(int argc,char **argv){ g_argc=argc; g_argv=argv;");
  puts("  volatile unsigned char sx_gcanchor=0;");
  puts("  int (*volatile sx_entry)(void)=sx_prog;");
  puts("  sx_gc_init((void*)&sx_gcanchor);");
  puts("  return sx_entry();");
  puts("}");
  return 0;
}
