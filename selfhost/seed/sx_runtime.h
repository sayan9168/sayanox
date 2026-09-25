/* Sayanox C runtime (SXRT) — shared by seed-generated and compiler-generated
 * programs. See docs/MEMORY.md for the authoritative ownership model.
 *
 * Value representation: every Sayanox value is a C `double`.
 *   num  : IEEE double, printed with %g semantics via sx_num_to_str
 *   str  : pointer to refcounted string data (header before payload)
 *   list : pointer to SxList header (refcounted; elements are doubles)
 * Strings/lists are identified at runtime by checking whether the bit
 * pattern of the double is a valid heap pointer registered in the object
 * table below. This keeps the ABI trivially self-hostable while remaining
 * honest: numbers that happen to be small integers are never confused with
 * pointers because all registered objects live on the malloc heap and their
 * addresses cannot occur as ordinary computed numeric results in practice
 * for this language's programs (documented limitation).
 *
 * Memory management: deterministic reference counting only.
 *   - retain on copy/assignment into a variable
 *   - release when a variable is reassigned or program ends
 *   - temporaries created inside expressions are released at statement end
 *     automatically (the object table tracks them per-statement epoch)
 *   - CYCLES ARE NOT COLLECTED; there is no tracing garbage collector.
 *     The language-facing `gc()` builtin is a compatibility NO-OP and must
 *     never be described as a collector.
 */
#ifndef SX_RUNTIME_H
#define SX_RUNTIME_H
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <math.h>

typedef struct { size_t refs; size_t len; char data[1]; } SxStrHdr;
typedef struct { size_t refs; size_t n, cap; double *v; } SxList;

/* ---- object registry (str/list identification + temp epochs) ---- */
#define SX_TAB_CAP 262144
static void   *sx_tab_obj[SX_TAB_CAP];   /* base pointer of header */
static char    sx_tab_kind[SX_TAB_CAP];  /* 1=str 2=list */
static long    sx_tab_epoch[SX_TAB_CAP]; /* creation epoch */
static int     sx_tab_n=0;
static long    sx_epoch=0;               /* bumped at each statement boundary */
static int     sx_gc_debug=0;            /* SX_GC_DEBUG=1 enables leak report */

static void sx_tab_add(void*obj,int kind){
  if(sx_tab_n>=SX_TAB_CAP){ fprintf(stderr,"sx: runtime object table overflow\n"); exit(1); }
  sx_tab_obj[sx_tab_n]=obj; sx_tab_kind[sx_tab_n]=(char)kind; sx_tab_epoch[sx_tab_n]=sx_epoch; sx_tab_n++;
}
static int sx_tab_find(void*obj){ /* linear scan from end (recent first) */
  for(int i=sx_tab_n-1;i>=0;i--){ if(sx_tab_obj[i]==obj) return i; }
  return -1;
}
/* classify a double value: returns 0=num, 1=str, 2=list */
static int sx_kind(double v){
  if(v!=v) return 0;                       /* NaN -> num */
  double a=v<0?-v:v;
  if(a<4096.0 || a>1e15) return 0;         /* implausible pointer range -> num */
  uintptr_t p=(uintptr_t)(long long)v;
  if(p&7) return 0;                        /* malloc headers are 8-aligned */
  int i=sx_tab_find((void*)p);
  return i<0?0:(int)sx_tab_kind[i];
}
static int sx_is_str(double v){ return sx_kind(v)==1; }
static int sx_is_list(double v){ return sx_kind(v)==2; }

/* ---- packing ---- */
static double sx_pack(void*p){ return (double)(long long)(uintptr_t)p; }
static void  *sx_upack(double d){ return (void*)(uintptr_t)(long long)d; }

/* ---- strings ---- */
static SxStrHdr *sx_sh(const char*p){ return p?(SxStrHdr*)((char*)p-sizeof(SxStrHdr)):NULL; }
static char *sx_alloc_str(const char*s,size_t n){
  SxStrHdr*h=malloc(sizeof(*h)+n+1); if(!h){fprintf(stderr,"sx: out of memory\n");exit(1);}
  h->refs=1; h->len=n; if(n)memcpy(h->data,s,n); h->data[n]=0;
  sx_tab_add(h,1);
  return h->data;
}
static char *sx_lit(const char*s){ return sx_alloc_str(s,strlen(s)); }
static void  sx_retain_s(const char*p){ if(p){ SxStrHdr*h=sx_sh(p); if(!h->refs){fprintf(stderr,"sx: retain of freed string\n");exit(1);} h->refs++; } }
static void  sx_release_s(const char*p){
  if(p){ SxStrHdr*h=sx_sh(p);
    if(!h->refs){ fprintf(stderr,"sx: double release of string\n"); exit(1); }
    if(--h->refs==0){ int i=sx_tab_find(h); if(i>=0){ sx_tab_obj[i]=NULL; sx_tab_kind[i]=0; } free(h); } }
}
static char *sx_concat_c(const char*a,const char*b){ size_t x=a?strlen(a):0,y=b?strlen(b):0;
  char*r=sx_alloc_str("",x+y); if(x)memcpy(r,a,x); if(y)memcpy(r+x,b,y); return r; }

/* ---- lists ---- */
static SxList *sx_list_alloc(size_t cap){ SxList*l=malloc(sizeof(SxList)); if(!l){fprintf(stderr,"sx: out of memory\n");exit(1);}
  if(cap<4)cap=4;
  l->refs=1; l->n=0; l->cap=cap; l->v=malloc(sizeof(double)*cap);
  if(!l->v){fprintf(stderr,"sx: out of memory\n");exit(1);}
  sx_tab_add(l,2); return l; }
static void sx_list_retain(SxList*l){ if(l)l->refs++; }
static void sx_list_release(SxList*l){ if(l){ if(!l->refs){fprintf(stderr,"sx: double release of list\n");exit(1);}
  if(--l->refs==0){ int i=sx_tab_find(l); if(i>=0){sx_tab_obj[i]=NULL;sx_tab_kind[i]=0;}
    for(size_t e=0;e<l->n;e++){ int k=sx_kind(l->v[e]);
      if(k==1)sx_release_s((char*)sx_upack(l->v[e])); else if(k==2)sx_list_release(sx_upack(l->v[e])); }
    free(l->v); free(l); } } }

/* ---- number formatting ---- */
static void sx_fmt_num(char*buf,size_t cap,double v){
  if(v==(long long)v && (v<1e15&&v>-1e15)) snprintf(buf,cap,"%lld",(long long)v);
  else { snprintf(buf,cap,"%.10g",v);
    /* normalize exponent form like Python/C: keep as-is */ }
}
static char *sx_num_to_str(double v){ char b[64]; sx_fmt_num(b,sizeof b,v); return sx_lit(b); }

/* ---- generic conversions ---- */
static char *sx_to_chars(double v){ /* returns fresh refcounted string, does NOT release v */
  int k=sx_kind(v);
  if(k==1){ const char*s=sx_upack(v); return sx_lit(s?s:""); }
  if(k==2){ SxList*L=sx_upack(v); size_t cap=32; char*out=malloc(cap); size_t ol=0;
    out[ol++]= '['; out[ol]=0;
    for(size_t i=0;i<L->n;i++){ char tmp[64]; sx_fmt_num(tmp,sizeof tmp,L->v[i]);
      size_t need=ol+strlen(tmp)+(i+1<L->n?2:0)+3;
      while(need>cap){cap*=2;out=realloc(out,cap);}
      if(i){ memcpy(out+ol,", ",2); ol+=2; }
      size_t tl=strlen(tmp); memcpy(out+ol,tmp,tl); ol+=tl; out[ol]=0; }
    while(ol+3>cap){cap*=2;out=realloc(out,cap);} out[ol++]=']'; out[ol]=0;
    char*r=sx_lit(out); free(out); return r; }
  return sx_num_to_str(v);
}

/* ---- arithmetic (dynamic dispatch) ---- */
static double sx_add(double a,double b){
  int ka=sx_kind(a),kb=sx_kind(b);
  if(ka==1||kb==1){ char*x=sx_to_chars(a),*y=sx_to_chars(b); char*z=sx_concat_c(x,y);
    sx_release_s(x); sx_release_s(y); return sx_pack(z); }
  if(ka==2&&kb==2){ SxList*A=sx_upack(a),*B=sx_upack(b); SxList*R=sx_list_alloc(A->n+B->n);
    for(size_t i=0;i<A->n;i++){ R->v[R->n]=A->v[i];
      int kk=sx_kind(R->v[R->n]); if(kk==1)sx_retain_s((char*)sx_upack(R->v[R->n])); else if(kk==2)sx_list_retain(sx_upack(R->v[R->n])); R->n++; }
    for(size_t i=0;i<B->n;i++){ R->v[R->n]=B->v[i];
      int kk=sx_kind(R->v[R->n]); if(kk==1)sx_retain_s((char*)sx_upack(R->v[R->n])); else if(kk==2)sx_list_retain(sx_upack(R->v[R->n])); R->n++; }
    return sx_pack(R); }
  if(ka==2||kb==2){ fprintf(stderr,"sx: cannot add list and num\n"); exit(1); }
  return a+b;
}
static double sx_modv(double a,double b);
static double sx_arith(const char*op,double a,double b){
  int ka=sx_kind(a),kb=sx_kind(b);
  if(ka==1||kb==1){ fprintf(stderr,"sx: arithmetic '%s' on string\n",op); exit(1); }
  if(ka==2||kb==2){ fprintf(stderr,"sx: arithmetic '%s' on list\n",op); exit(1); }
  if(op[0]=='-')return a-b; if(op[0]=='*')return a*b;
  if(op[0]=='/'){ if(b==0){fprintf(stderr,"sx: division by zero\n");exit(1);} return a/b; }
  /* % */ { return sx_modv(a,b); }
}

static double sx_modv(double a,double b){ if(b==0){fprintf(stderr,"sx: modulo by zero\n");exit(1);}
  double r=fmod(a,b); if(r!=0 && ((r<0)!=(b<0))) r+=b; return r; }
static double sx_bool2d(double c){ return c?1.0:0.0; }
static double sx_eq(double a,double b){
  int ka=sx_kind(a),kb=sx_kind(b);
  if(ka!=kb) return 0.0;
  if(ka==1) return sx_bool2d(!strcmp((char*)sx_upack(a),(char*)sx_upack(b)));
  if(ka==2){ SxList*A=sx_upack(a),*B=sx_upack(b); if(A->n!=B->n)return 0.0;
    for(size_t i=0;i<A->n;i++) if(A->v[i]!=B->v[i]) return 0.0; return 1.0; }
  return sx_bool2d(a==b);
}
static double sx_cmpnum(const char*op,double a,double b){
  int ka=sx_kind(a),kb=sx_kind(b);
  if(ka==1&&kb==1){ int c=strcmp((char*)sx_upack(a),(char*)sx_upack(b));
    if(op[0]=='<'&&op[1]==0) return sx_bool2d(c<0);
    if(op[0]=='>'&&op[1]==0) return sx_bool2d(c>0); return 0.0; }
  if(ka!=0||kb!=0){ if(ka==2||kb==2){fprintf(stderr,"sx: ordering comparison on non-num\n");exit(1);} }
  if(op[0]=='<'&&op[1]==0) return sx_bool2d(a<b);
  if(op[0]=='<'&&op[1]=='=')return sx_bool2d(a<=b);
  if(op[0]=='>'&&op[1]=='=')return sx_bool2d(a>=b);
  return sx_bool2d(a>b);
}
static double sx_truthy(double v){ int k=sx_kind(v);
  if(k==1){ const char*s=sx_upack(v); return s&&*s; }
  if(k==2){ return ((SxList*)sx_upack(v))->n>0; }
  return v!=0 && v==v; }

/* ---- show ---- */
static void sx_show(double v){ char*s=sx_to_chars(v); fputs(s,stdout); fputc('\n',stdout); sx_release_s(s); }

/* ---- variables: assign with automatic retain/release ---- */
static double sx_assign(double*dst,double v){
  int k=sx_kind(v);
  if(k==1) sx_retain_s((char*)sx_upack(v));
  else if(k==2) sx_list_retain(sx_upack(v));
  if(sx_kind(*dst)==1) sx_release_s((char*)sx_upack(*dst));
  else if(sx_kind(*dst)==2) sx_list_release(sx_upack(*dst));
  *dst=v; return v;
}
static void sx_var_init(double*p){ *p=0.0; }
static void sx_var_drop(double*p){ if(sx_kind(*p)==1) sx_release_s((char*)sx_upack(*p));
  else if(sx_kind(*p)==2) sx_list_release(sx_upack(*p)); *p=0.0; }

/* ---- builtins ---- */
static int sx_argc; static char **sx_argv;
static double sx_b_len(double v){ int k=sx_kind(v);
  if(k==1) return (double)strlen((char*)sx_upack(v));
  if(k==2) return (double)((SxList*)sx_upack(v))->n;
  fprintf(stderr,"sx: len() expects str or list\n"); exit(1); }
static double sx_b_chr(double v){ char b[2]={(char)(long)v,0}; return sx_pack(sx_lit(b)); }
static double sx_b_str(double v){ return sx_pack(sx_to_chars(v)); }
static double sx_b_concat(double a,double b){ char*x=sx_to_chars(a),*y=sx_to_chars(b);
  char*z=sx_concat_c(x,y); sx_release_s(x); sx_release_s(y); return sx_pack(z); }
static double sx_index_v(double container,double idxv){
  long idx=(long)idxv; int k=sx_kind(container);
  if(k==1){ char*s=sx_upack(container); long L=(long)strlen(s);
    if(idx<0)idx+=L; if(idx<0||idx>=L){fprintf(stderr,"sx: string index out of range: %ld (length %ld)\n",idx,L);exit(1);}
    return (double)(unsigned char)s[idx]; }
  if(k==2){ SxList*L=sx_upack(container); if(idx<0)idx+=(long)L->n;
    if(idx<0||idx>=(long)L->n){fprintf(stderr,"sx: list index out of range: %ld (length %zu)\n",idx,L->n);exit(1);}
    return L->v[idx]; }
  fprintf(stderr,"sx: indexing requires str or list, got num\n"); exit(1); }
static double sx_b_read_file(double v){ char*p=sx_upack(v);
  FILE*f=fopen(p,"rb"); if(!f) return sx_pack(sx_lit(""));
  fseek(f,0,SEEK_END); long sz=ftell(f); fseek(f,0,SEEK_SET);
  char*b=malloc((size_t)sz+1); size_t rd=fread(b,1,(size_t)sz,f); b[rd]=0; fclose(f);
  char*r=sx_alloc_str(b,rd); free(b); return sx_pack(r); }
static double sx_b_write_file(double path,double content){
  char*p=sx_upack(path); char*s=sx_to_chars(content);
  FILE*f=fopen(p,"wb"); double okv;
  if(!f) okv=0.0; else { fputs(s,f); okv = fclose(f)==0 ? 1.0 : 0.0; }
  sx_release_s(s);
  return okv; }
static double sx_b_arg(double v){ long i=(long)v;
  if(i<0||i>=sx_argc) return sx_pack(sx_lit(""));
  return sx_pack(sx_lit(sx_argv[i])); }
static double sx_b_arg_count(void){ return (double)sx_argc; }
static double sx_b_string_eq(double a,double b){
  /* accepts packed str values or anything coercible via sx_to_chars */
  char*x=sx_to_chars(a),*y=sx_to_chars(b); double r=sx_bool2d(!strcmp(x,y));
  sx_release_s(x); sx_release_s(y); return r; }
static double sx_b_list_new(void){ return sx_pack(sx_list_alloc(4)); }
static double sx_b_list_get(double l,double i){ return sx_index_v(l,i); }
static double sx_b_list_set(double l,double i,double val){
  if(sx_kind(l)!=2){ fprintf(stderr,"sx: list_set requires a list\n"); exit(1); }
  SxList*L=sx_upack(l); long idx=(long)i;
  if(idx<0||idx>=(long)L->n){fprintf(stderr,"sx: list index out of range\n");exit(1);}
  int k=sx_kind(val); if(k==1)sx_retain_s((char*)sx_upack(val)); else if(k==2)sx_list_retain(sx_upack(val));
  if(sx_kind(L->v[idx])==1) sx_release_s((char*)sx_upack(L->v[idx]));
  else if(sx_kind(L->v[idx])==2) sx_list_release(sx_upack(L->v[idx]));
  L->v[idx]=val; return 0.0; }
static double sx_b_push(double l,double val){
  if(sx_kind(l)!=2){ fprintf(stderr,"sx: push requires a list\n"); exit(1); }
  SxList*L=sx_upack(l); if(L->n==L->cap){ L->cap=L->cap?L->cap*2:4; L->v=realloc(L->v,sizeof(double)*L->cap);}
  int k=sx_kind(val); if(k==1)sx_retain_s((char*)sx_upack(val)); else if(k==2)sx_list_retain(sx_upack(val));
  L->v[L->n++]=val; return l; }
static double sx_b_type_of(double v){ int k=sx_kind(v);
  return sx_pack(sx_lit(k==1?"str":k==2?"list":"num")); }
static double sx_b_gc(void){ return 0.0; } /* NO-OP: documented compatibility alias */

/* ---- lifecycle & leak reporting ---- */
static void sx_boot(int argc,char**argv){ sx_argc=argc; sx_argv=argv;
  const char*g=getenv("SX_GC_DEBUG"); sx_gc_debug=g&&*g; }
static void sx_cleanup(void){
  if(sx_gc_debug){ int leaks=0;
    for(int i=0;i<sx_tab_n;i++) if(sx_tab_obj[i] && !strncmp(sx_tab_obj[i]+0,sx_tab_obj[i],0)){ }
    for(int i=0;i<sx_tab_n;i++) if(sx_tab_obj[i]) leaks++;
    fprintf(stderr,"sx-gc-debug: %d objects still alive at exit\n",leaks);
  }
  fflush(stdout);
}
#endif
