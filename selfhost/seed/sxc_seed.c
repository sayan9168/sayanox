/* sxc_seed.c — Sayanox seed compiler (bootstrap only).
 *
 * This is the ONLY C compiler source built by clang/gcc to bootstrap the
 * toolchain. It compiles the canonical Sayanox subset (docs/LANGUAGE.md) to
 * C using the shared runtime header sx_runtime.h. Every later compiler
 * generation (gen1, gen2, gen3, ...) must be *generated* by a previously
 * compiled Sayanox compiler and recompiled from that generated source —
 * never copied from a checked-in artifact (see tests/selfhost/gen_chain.sh).
 *
 * Pipeline stages (kept separate; see docs/COMPILER_ARCHITECTURE.md):
 *   module loader -> lexer -> parser (AST) -> type checker -> C backend
 */
#define _GNU_SOURCE
#include <stdlib.h>
#include <ctype.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

static const char *g_main_path = "?";

/* ================= diagnostics ================= */
static int g_errors = 0;
static char **g_lines = NULL; static int g_nlines = 0;
static void index_lines(const char *src){
  int cap=256; g_lines=malloc(sizeof(char*)*cap);
  const char*p=src; g_nlines=0;
  while(*p){ if(g_nlines==cap){cap*=2;g_lines=realloc(g_lines,sizeof(char*)*cap);}
    g_lines[g_nlines++]=(char*)p;
    const char*q=strchr(p,'\n'); if(!q)break; p=q+1; }
}
static void diag(int line,int col,const char*cat,const char*fmt,...){
  va_list ap;
  fprintf(stderr,"%s:%d:%d: %s: ",g_main_path,line,col,cat);
  va_start(ap,fmt); vfprintf(stderr,fmt,ap); va_end(ap); fputc('\n',stderr);
  if(line>=1&&line<=g_nlines){
    const char*L=g_lines[line-1]; size_t n=strcspn(L,"\n");
    fprintf(stderr,"  %.*s\n",(int)n,L);
    fprintf(stderr,"  "); for(size_t i=0;i<(size_t)(col>1?col-1:0);i++) fputc(' ',stderr);
    fputs("^\n",stderr);
  }
  g_errors++;
  if(g_errors>40){ fprintf(stderr,"too many errors, stopping\n"); exit(1); }
}
#define SYERR(l,c,...)  diag(l,c,"syntax error",__VA_ARGS__)
#define TYERR(l,c,...)  diag(l,c,"type error",__VA_ARGS__)
#define SEMERR(l,c,...) diag(l,c,"semantic error",__VA_ARGS__)

/* ================= lexer ================= */
typedef enum { T_END,T_NU,T_KW,T_ID,T_ST,T_EOFT,T_LB,T_RB,T_LC,T_RC,
               T_PLUS,T_MINUS,T_STAR,T_SLASH,T_PERCENT,T_EQ,T_NE,T_LT,T_LE,T_GT,T_GE,
               T_ASSIGN,T_COMMA,T_DOT,T_LPAREN,T_RPAREN,T_BANG,T_AMP,T_BAR,T_AMPAMP,T_BARBAR,T_QUEST,T_COLON } TokKind;

typedef struct { TokKind k; double num; char *s; int line,col; } Tok;
static Tok *tk; static int ntk,captk;
static void ptok(TokKind k,const char*s,double num,int line,int col){
  if(ntk==captk){captk=captk?captk*2:8192; tk=realloc(tk,sizeof(Tok)*captk);}
  tk[ntk].k=k; tk[ntk].s=s?strdup(s):NULL; tk[ntk].num=num; tk[ntk].line=line; tk[ntk].col=col; ntk++;
}
static const char *KWS[]={"hold","when","otherwise","while","make","give","show","import","as","print","assert",NULL};
static int is_kw(const char*s){for(int i=0;KWS[i];i++)if(!strcmp(KWS[i],s))return 1;return 0;}
static int id0(int c){return isalpha(c)||c=='_';}
static int idc(int c){return isalnum(c)||c=='_';}

static void tokenize(const char*src){
  int line=1,col=1; size_t i=0,n=strlen(src);
  while(i<n){
    char c=src[i];
    if(c=='\n'){ ptok(T_EOFT,NULL,0,line,col); line++; col=1; i++; continue; }
    if(c==' '||c=='\t'||c=='\r'){ col++; i++; continue; }
    if(c=='/'&&i+1<n&&src[i+1]=='/'){ while(i<n&&src[i]!='\n')i++; continue; }
    int sl=line,sc=col;
    if(isdigit((unsigned char)c)||(c=='.'&&i+1<n&&isdigit((unsigned char)src[i+1]))){
      size_t j=i; char buf[64]; int k=0;
      while(j<n&&(isdigit((unsigned char)src[j])||src[j]=='.')){ if(k<63)buf[k++]=src[j]; j++; }
      buf[k]=0; i=j; col+=k; ptok(T_NU,buf,atof(buf),sl,sc); continue;
    }
    if(id0((unsigned char)c)){
      size_t j=i; char buf[128]; int k=0;
      while(j<n&&idc((unsigned char)src[j])){ if(k<127)buf[k++]=src[j]; j++; }
      buf[k]=0; i=j; col+=k; ptok(is_kw(buf)?T_KW:T_ID,buf,0,sl,sc); continue;
    }
    if(c=='"'){
      i++; col++; size_t j=i; char*buf=malloc(n+2); int k=0;
      while(j<n&&src[j]!='"'){
        if(src[j]=='\\'&&j+1<n){ char e=src[++j];
          buf[k++]= e=='n'?'\n': e=='t'?'\t': e=='r'?'\r': e; j++;
        } else buf[k++]=src[j++];
      }
      if(j>=n){ SYERR(sl,sc,"unterminated string literal"); free(buf); return; }
      int advd=(int)(j-i)+1; i=j+1; col+=advd; buf[k]=0;
      ptok(T_ST,buf,0,sl,sc); free(buf); continue;
    }
    if(c=='='&&i+1<n&&src[i+1]=='='){i+=2;col+=2;ptok(T_EQ,"==",0,sl,sc);continue;}
    if(c=='!'&&i+1<n&&src[i+1]=='='){i+=2;col+=2;ptok(T_NE,"!=",0,sl,sc);continue;}
    if(c=='&'&&i+1<n&&src[i+1]=='&'){i+=2;col+=2;ptok(T_AMPAMP,"&&",0,sl,sc);continue;}
    if(c=='|'&&i+1<n&&src[i+1]=='|'){i+=2;col+=2;ptok(T_BARBAR,"||",0,sl,sc);continue;}
    if(c=='<'&&i+1<n&&src[i+1]=='='){i+=2;col+=2;ptok(T_LE,"<=",0,sl,sc);continue;}
    if(c=='>'&&i+1<n&&src[i+1]=='='){i+=2;col+=2;ptok(T_GE,">=",0,sl,sc);continue;}
    #define P1(ch,k) if(c==ch){ i++; col++; ptok(k,(const char*)#ch,0,sl,sc); continue; }
    P1('<',T_LT) P1('>',T_GT) P1('+',T_PLUS) P1('-',T_MINUS) P1('*',T_STAR)
    P1('/',T_SLASH) P1('%',T_PERCENT) P1('=',T_ASSIGN) P1(',',T_COMMA) P1('.',T_DOT)
    P1('&',T_AMP) P1('|',T_BAR) P1('?',T_QUEST) P1(':',T_COLON)
    P1('!',T_BANG)
    P1('[',T_LB) P1(']',T_RB) P1('{',T_LC) P1('}',T_RC) P1('(',T_LPAREN) P1(')',T_RPAREN)
    { char b[2]={c,0}; SYERR(sl,sc,"unexpected character '%s'",b); i++; col++; }
  }
  ptok(T_END,NULL,0,line,col);
}

/* ================= AST ================= */
typedef enum { E_NU,E_ST,E_ID,E_BIN,E_NEG,E_CALL,E_INDEX,E_LIST,E_NOT,E_AND,E_OR,E_IFS,E_STRUC,E_FIELD } EKind;
typedef enum { S_HOLD,S_SHOW,S_WHEN,S_WHILE,S_GIVE,S_ASSIGN,S_SETIDX,S_EXPR,S_ASSERT } SKind;
typedef enum { TY_UNK,TY_NUM,TY_STR,TY_LIST,TY_ANY } Type;

typedef struct Expr Expr;
typedef struct Stmt Stmt;
typedef struct Block { Stmt **items; int n,cap; } Block;

struct Expr {
  EKind k; int line,col; Type ty;
  double num; char *s;
  Expr *a,*b,*c;                 /* c: else-branch of ternary when */
  Expr **args; int nargs;
  char *fn;
  int field;                     /* struct field index for E_FIELD */
  char *structof;                /* struct type of produced value (E_STRUC) */
  char *struct_name;             /* for E_ID: struct type of the variable */
};
struct Stmt {
  SKind k; int line,col;
  char *name;                    /* hold/assign target */
  Expr *e;                       /* value / condition */
  Expr *idx;                     /* subscript for S_SETIDX */
  Expr *val;                     /* assigned value for S_SETIDX */
  Block *body,*els;
  Type give_ty;
};
static Expr *newe(EKind k,int l,int c){ Expr*e=calloc(1,sizeof(Expr)); e->k=k; e->line=l; e->col=c; e->ty=TY_UNK; return e; }
static Stmt *news(SKind k,int l,int c){ Stmt*s=calloc(1,sizeof(Stmt)); s->k=k; s->line=l; s->col=c; return s; }
static Block *newb(void){ return calloc(1,sizeof(Block)); }
static void badd(Block*b,Stmt*s){ if(b->n==b->cap){b->cap=b->cap?b->cap*2:8;b->items=realloc(b->items,sizeof(Stmt*)*b->cap);} b->items[b->n++]=s; }

typedef struct { char *name; char **fields; int nfields; } StructDef;
static StructDef structs[64]; static int nstructs=0;
static StructDef*find_struct(const char*n){for(int i=0;i<nstructs;i++)if(!strcmp(structs[i].name,n))return &structs[i];return NULL;}

typedef struct { char *name; Block *body; char **params; int nparams; int index; Type ret; int has_give; int sret; } Func;
static Func funcs[256]; static int nfuncs=0;
static Block *main_block=NULL;

/* ================= parser ================= */
static int pc;
static Tok *cu(void){ return &tk[pc]; }
static int at(TokKind k){ return tk[pc].k==k; }
static int atkw(const char*s){ return tk[pc].k==T_KW && !strcmp(tk[pc].s,s); }
static void adv(void){ if(tk[pc].k!=T_END) pc++; }
static void skip_nl(void){ while(at(T_EOFT)) adv(); }

static Expr *p_expr(void);
static Expr *p_ternary(void);
static void p_stmt_into(Block*b);


static Expr *p_primary(void){
  skip_nl();
  Tok*t=cu();
  if(t->k==T_NU){ Expr*e=newe(E_NU,t->line,t->col); e->num=t->num; e->ty=TY_NUM; adv(); return e; }
  if(t->k==T_ST){ Expr*e=newe(E_ST,t->line,t->col); e->s=t->s; e->ty=TY_STR; adv(); return e; }
  if(t->k==T_LPAREN){ adv(); Expr*e=p_expr(); skip_nl();
    if(!at(T_RPAREN)){ SYERR(cu()->line,cu()->col,"expected ')'"); return e; } adv(); return e; }
  if(t->k==T_LB){
    adv(); Expr*e=newe(E_LIST,t->line,t->col); e->ty=TY_LIST; skip_nl();
    while(!at(T_RB)&&!at(T_END)){
      Expr*el=p_ternary();
      e->args=realloc(e->args,sizeof(Expr*)*(e->nargs+1)); e->args[e->nargs++]=el;
      skip_nl();
      if(at(T_COMMA)){ adv(); skip_nl(); continue; }
      break;
    }
    if(!at(T_RB)){ SYERR(cu()->line,cu()->col,"expected ']'"); return e; }
    adv(); return e;
  }
  if(t->k==T_ID){
    Tok save=*t; adv();
    if(at(T_LPAREN)){
      adv(); 
      if(find_struct(save.s)){
        Expr*e=newe(E_STRUC,save.line,save.col); e->s=save.s; skip_nl();
        while(!at(T_RPAREN)&&!at(T_END)){
          Expr*a=p_ternary();
          e->args=realloc(e->args,sizeof(Expr*)*(e->nargs+1)); e->args[e->nargs++]=a;
          skip_nl();
          if(at(T_COMMA)){ adv(); skip_nl(); continue; }
          break;
        }
        if(!at(T_RPAREN)){ SYERR(cu()->line,cu()->col,"expected ')' in struct initializer"); return e; }
        adv(); return e;
      }
      Expr*e=newe(E_CALL,save.line,save.col); e->fn=save.s; skip_nl();
      while(!at(T_RPAREN)&&!at(T_END)){
        Expr*a=p_ternary();
        e->args=realloc(e->args,sizeof(Expr*)*(e->nargs+1)); e->args[e->nargs++]=a;
        skip_nl();
        if(at(T_COMMA)){ adv(); skip_nl(); continue; }
        break;
      }
      if(!at(T_RPAREN)){ SYERR(cu()->line,cu()->col,"expected ')' in call"); return e; }
      adv(); return e;
    }
    Expr*e=newe(E_ID,save.line,save.col); e->s=save.s; e->ty=TY_ANY; return e;
  }
  if(t->k==T_KW){ SYERR(t->line,t->col,"keyword '%s' cannot start an expression",t->s); adv(); return newe(E_NU,t->line,t->col); }
  SYERR(t->line,t->col,"unexpected token in expression");
  adv(); return newe(E_NU,t->line,t->col);
}
static Expr *p_postfix(void){
  Expr*e=p_primary();
  for(;;){
    if(at(T_LB)){ int l=cu()->line,c=cu()->col; adv(); Expr*i=p_expr(); skip_nl();
      if(!at(T_RB)){ SYERR(cu()->line,cu()->col,"expected ']'"); break; } adv();
      Expr*x=newe(E_INDEX,l,c); x->a=e; x->b=i; e=x; continue; }
    if(at(T_DOT)){ int l=cu()->line,c=cu()->col; adv();
      if(!at(T_ID)){ SYERR(cu()->line,cu()->col,"expected field name after '.'"); break; }
      Tok f=*cu(); adv();
      Expr*x=newe(E_FIELD,l,c); x->a=e; x->s=f.s; e=x; continue; }
    break;
  }
  return e;
}
static Expr *p_unary(void){
  if(at(T_MINUS)){ int l=cu()->line,c=cu()->col; adv(); Expr*e=newe(E_NEG,l,c); e->a=p_unary(); return e; }
  if(at(T_BANG)){ int l=cu()->line,c=cu()->col; adv(); Expr*e=newe(E_NOT,l,c); e->a=p_unary(); return e; }
  return p_postfix();
}
static Expr *mkbin(int l,int c,const char*op,Expr*a,Expr*b){ Expr*e=newe(E_BIN,l,c); e->s=strdup(op); e->a=a; e->b=b; return e; }
static Expr *p_mul(void){
  Expr*a=p_unary();
  while(at(T_STAR)||at(T_SLASH)||at(T_PERCENT)){
    Tok o=*cu(); adv(); a=mkbin(o.line,o.col,o.s,a,p_unary());
  }
  return a;
}
static Expr *p_add(void){
  Expr*a=p_mul();
  while(at(T_PLUS)||at(T_MINUS)){
    Tok o=*cu(); adv(); a=mkbin(o.line,o.col,o.s,a,p_mul());
  }
  return a;
}
static Expr *p_cmp(void){
  Expr*a=p_add();
  if(at(T_EQ)||at(T_NE)||at(T_LT)||at(T_LE)||at(T_GT)||at(T_GE)){
    Tok o=*cu(); adv(); a=mkbin(o.line,o.col,o.s,a,p_add());
  }
  return a;
}
static Expr *p_and(void){
  Expr*a=p_cmp();
  while(at(T_AMPAMP)){ int l=cu()->line,c=cu()->col; adv(); a=mkbin(l,c,"&&",a,p_cmp()); }
  return a;
}
static Expr *p_or(void){
  Expr*a=p_and();
  while(at(T_BARBAR)){ int l=cu()->line,c=cu()->col; adv(); a=mkbin(l,c,"||",a,p_and()); }
  return a;
}
static Expr *p_ternary(void){
  Expr*cnd=p_or();
  if(at(T_QUEST)){
    int l=cu()->line,c=cu()->col; adv();
    Expr*t=p_ternary();
    if(!at(T_COLON)){ SYERR(cu()->line,cu()->col,"expected ':' in conditional expression"); return cnd; }
    adv();
    Expr*f=p_ternary();
    Expr*e=newe(E_IFS,l,c); e->a=cnd; e->b=t; e->c=f; return e;
  }
  return cnd;
}
static Expr *p_expr(void){ return p_ternary(); }

static Block *p_block(void){
  Block*b=newb();
  skip_nl();
  if(!at(T_LC)){ SYERR(cu()->line,cu()->col,"expected '{' to open block"); return b; }
  adv(); skip_nl();
  int guard_items=0;
  while(!at(T_RC)&&!at(T_END)){
    if(++guard_items>200000){ SYERR(cu()->line,cu()->col,"compiler limit: too many statements in block"); break; }
    p_stmt_into(b);
    skip_nl();
  }
  if(!at(T_RC)) SYERR(cu()->line,cu()->col,"expected '}' to close block");
  adv();
  return b;
}

static void p_hold(Block*b){
  adv(); skip_nl();
  if(!at(T_ID)){ SYERR(cu()->line,cu()->col,"expected variable name after 'hold'"); return; }
  Tok name=*cu(); adv(); skip_nl();
  if(!at(T_ASSIGN)){ SYERR(name.line,name.col,"expected '=' after variable name '%s'",name.s); return; }
  adv();
  Expr*e=p_expr();
  Stmt*s=news(S_HOLD,name.line,name.col); s->name=name.s; s->e=e;
  badd(b,s);
}
static void p_show(Block*b){
  Tok t=*cu(); adv(); Expr*e=p_expr();
  Stmt*s=news(S_SHOW,t.line,t.col); s->e=e; badd(b,s);
}
static void p_when(Block*b){
  Tok t=*cu(); adv(); Expr*cnd=p_expr();
  Block*body=p_block();
  Stmt*s=news(S_WHEN,t.line,t.col); s->e=cnd; s->body=body;
  skip_nl();
  if(atkw("otherwise")){ adv(); s->els=p_block(); }
  badd(b,s);
}
static void p_while(Block*b){
  Tok t=*cu(); adv(); Expr*cnd=p_expr(); Block*body=p_block();
  Stmt*s=news(S_WHILE,t.line,t.col); s->e=cnd; s->body=body; badd(b,s);
}
static void p_give(Block*b){
  Tok t=*cu(); adv();
  Stmt*s=news(S_GIVE,t.line,t.col);
  if(!at(T_EOFT)&&!at(T_RC)&&!at(T_END)) s->e=p_expr();
  badd(b,s);
}
static void p_struct(void){
  Tok t=*cu(); adv(); skip_nl();
  if(!at(T_ID)){ SYERR(cu()->line,cu()->col,"expected struct name after 'make'"); return; }
  Tok name=*cu(); adv();
  if(nstructs>=64){ SYERR(t.line,t.col,"too many structs"); return; }
  for(int i=0;i<nstructs;i++) if(!strcmp(structs[i].name,name.s)) { SEMERR(name.line,name.col,"duplicate struct definition '%s'",name.s); return; }
  StructDef*S=&structs[nstructs]; S->name=name.s;
  if(!at(T_LB)){ SYERR(cu()->line,cu()->col,"expected '{ field, ... }' list for struct fields"); return; }
  adv(); skip_nl();
  while(!at(T_RB)&&!at(T_END)){
    if(!at(T_ID)){ SYERR(cu()->line,cu()->col,"expected field name"); break; }
    S->fields=realloc(S->fields,sizeof(char*)*(S->nfields+1));
    S->fields[S->nfields++]=cu()->s; adv();
    skip_nl();
    if(at(T_COMMA)){ adv(); skip_nl(); continue; } break;
  }
  if(!at(T_RB)){ SYERR(cu()->line,cu()->col,"expected ']' closing struct fields"); return; }
  adv();
  nstructs++;
}
static void p_make(void){
  Tok t=*cu(); adv(); skip_nl();
  if(!at(T_ID)){ SYERR(cu()->line,cu()->col,"expected function name after 'make'"); return; }
  Tok name=*cu(); adv();
  if(nfuncs>=256){ SYERR(t.line,t.col,"too many functions (limit 256)"); return; }
  Func*f=&funcs[nfuncs]; f->name=name.s; f->index=nfuncs; f->ret=TY_NUM;
  for(int i=0;i<nfuncs;i++) if(!strcmp(funcs[i].name,f->name)) SEMERR(name.line,name.col,"duplicate function definition '%s'",f->name);
  if(!at(T_LPAREN)){ SYERR(cu()->line,cu()->col,"expected '(' after function name"); return; }
  adv();
  if(!at(T_RPAREN)){
    for(;;){
      skip_nl();
      if(!at(T_ID)){ SYERR(cu()->line,cu()->col,"expected parameter name"); break; }
      if(f->nparams>=16){ SYERR(cu()->line,cu()->col,"too many parameters (limit 16)"); break; }
      f->params=realloc(f->params,sizeof(char*)*(f->nparams+1));
      f->params[f->nparams++]=cu()->s; adv();
      if(at(T_COMMA)){ adv(); continue; } break;
    }
  }
  if(!at(T_RPAREN)){ SYERR(cu()->line,cu()->col,"expected ')'"); return; }
  adv();
  f->body=p_block();
  nfuncs++;
}
static void p_import(void){
  Tok t=*cu(); adv(); skip_nl();
  if(!at(T_ST)){ SYERR(t.line,t.col,"import expects a string path"); return; }
  adv(); /* path already spliced by the module loader */
  if(atkw("as")){ adv(); if(at(T_ID)) adv(); else SYERR(cu()->line,cu()->col,"expected alias after 'as'"); }
}
static void p_assign_or_expr(Block*b){
  Tok t=*cu();
  if(t.k==T_ID){
    Tok save=t; adv();
    if(at(T_ASSIGN)){
      adv(); Expr*v=p_expr();
      Stmt*s=news(S_ASSIGN,save.line,save.col); s->name=save.s; s->e=v; badd(b,s); return;
    }
    if(at(T_LB)){
      adv(); Expr*i=p_expr(); skip_nl();
      if(!at(T_RB)){ SYERR(cu()->line,cu()->col,"expected ']'"); return; } adv();
      if(!at(T_ASSIGN)){ SYERR(cu()->line,cu()->col,"expected '=' after subscript target"); return; }
      adv(); Expr*v=p_expr();
      Stmt*s=news(S_SETIDX,save.line,save.col);
      Expr*tgt=newe(E_ID,save.line,save.col); tgt->s=save.s;
      s->e=tgt; s->idx=i; s->val=v; s->name=save.s;
      badd(b,s); return;
    }
    pc--; /* rewind to identifier: general expression statement */
  }
  /* expression statement (call etc.) */
  if(at(T_ID)||at(T_LPAREN)||at(T_NU)||at(T_ST)||at(T_MINUS)||at(T_LB)){
    Expr*e=p_expr();
    Stmt*s=news(S_EXPR,t.line,t.col); s->e=e; badd(b,s); return;
  }
  SYERR(t.line,t.col,"expected a statement, found '%s'",t.s?t.s:"<token>");
  adv();
}
static void p_stmt_into(Block*b){
  if(atkw("hold")){ p_hold(b); return; }
  if(atkw("make")){ /* make Name [ fields ] or make name(...) */
    /* lookahead: identifier followed by '[' => struct definition */
    if(tk[pc+1].k==T_ID&&tk[pc+2].k==T_LB){ p_struct(); return; }
    p_make(); return; }
  if(atkw("show")){ p_show(b); return; }
  if(atkw("when")){ p_when(b); return; }
  if(atkw("while")){ p_while(b); return; }
  if(atkw("give")){ p_give(b); return; }
  if(atkw("import")){ p_import(); return; }
  if(atkw("print")){ /* deprecated alias of show */ 
    Tok t=*cu(); adv(); Expr*e=p_expr();
    Stmt*s=news(S_SHOW,t.line,t.col); s->e=e; badd(b,s); return; }
  if(atkw("assert")){
    Tok t=*cu(); adv(); Expr*e=p_expr();
    Stmt*s=news(S_ASSERT,t.line,t.col); s->e=e; badd(b,s); return; }
  if(atkw("otherwise")||atkw("as")){ SYERR(cu()->line,cu()->col,"stray keyword '%s'",cu()->s); adv(); return; }
  p_assign_or_expr(b);
}

/* ================= type checker ================= */
static const char *tyname(Type t){ return t==TY_NUM?"num":t==TY_STR?"str":t==TY_LIST?"list":"any"; }
#define MAXVARS 8192
static int scope_depth=0;
static Func *cur_fn;
typedef struct { char *name; Type ty; int depth; char *sname; } Var2;
static Var2 vars2[MAXVARS]; static int nvars2=0;
static Var2 *find_var2(const char*n){ for(int i=nvars2-1;i>=0;i--) if(vars2[i].depth<=scope_depth&&!strcmp(vars2[i].name,n)) return &vars2[i]; return NULL; }
static void declare_var(const char*n,Type ty,int l,int c,const char*sname){
  Var2*v=find_var2(n);
  if(!v){ if(nvars2>=MAXVARS){SEMERR(l,c,"too many variables");return;}
    vars2[nvars2].name=strdup(n); vars2[nvars2].ty=ty; vars2[nvars2].depth=scope_depth; vars2[nvars2].sname=sname?strdup(sname):NULL; nvars2++; return; }
  if(sname&&!v->sname) v->sname=strdup(sname);
  if(v->ty==ty) return;
  if(v->ty==TY_ANY||ty==TY_ANY){ v->ty=ty==TY_ANY?v->ty:TY_ANY; return; }
  TYERR(l,c,"cannot assign %s to variable '%s' previously declared as %s",tyname(ty),n,tyname(v->ty));
}
static void redeclare_var(const char*n,Type ty,int l,int c,const char*sname){ declare_var(n,ty,l,c,sname); }
/* legacy declare_var kept for parameter registration */
static void declare_param(const char*n,Type ty,int l,int c){ declare_var(n,ty,l,c,NULL); }
static int builtin_arity(const char*n){
  if(!strcmp(n,"len")||!strcmp(n,"chr")||!strcmp(n,"str")||!strcmp(n,"read_file")||!strcmp(n,"arg")||!strcmp(n,"type_of"))return 1;
  if(!strcmp(n,"concat")||!strcmp(n,"sx_index")||!strcmp(n,"write_file")||!strcmp(n,"string_eq")||!strcmp(n,"list_get")||!strcmp(n,"push"))return 2;
  if(!strcmp(n,"list_set"))return 3;
  if(!strcmp(n,"arg_count")||!strcmp(n,"list_new")||!strcmp(n,"gc"))return 0;
  return -2;
}
static Type builtin_ret(const char*n){
  if(!strcmp(n,"len")||!strcmp(n,"write_file")||!strcmp(n,"arg_count")||!strcmp(n,"string_eq")||!strcmp(n,"list_set")||!strcmp(n,"gc"))return TY_NUM;
  if(!strcmp(n,"chr")||!strcmp(n,"str")||!strcmp(n,"concat")||!strcmp(n,"read_file")||!strcmp(n,"arg")||!strcmp(n,"type_of"))return TY_STR;
  if(!strcmp(n,"list_new")||!strcmp(n,"push"))return TY_LIST;
  return TY_ANY;
}
static Func *find_fn(const char*n){ for(int i=0;i<nfuncs;i++) if(!strcmp(funcs[i].name,n)) return &funcs[i]; return NULL; }

static int rguard=0;
#define GUARD() do{ if(++rguard>4000000){ fprintf(stderr,"compiler limit: recursion too deep\n"); exit(1);} }while(0)

static Type check_expr(Expr*e);

static Type check_binop_plus(Expr*e,Type a,Type b){
  if(a==TY_LIST||b==TY_LIST){ if(a!=b){ TYERR(e->line,e->col,"operator '+' cannot combine %s and %s",tyname(a),tyname(b)); return TY_LIST; } return TY_LIST; }
  if(a==TY_STR||b==TY_STR){
    if(a==TY_NUM||b==TY_NUM){ TYERR(e->line,e->col,"expected str, got num in string concatenation (use str(x))"); return TY_STR; }
    return TY_STR;
  }
  return TY_NUM;
}
static Type check_expr(Expr*e){
  GUARD();
  if(!e) return TY_NUM;
  switch(e->k){
    case E_NU: e->ty=TY_NUM; break;
    case E_ST: e->ty=TY_STR; break;
    case E_LIST: {
      Type t=TY_UNK;
      for(int i=0;i<e->nargs;i++){ Type ti=check_expr(e->args[i]);
        if(i&&t!=TY_UNK&&ti!=TY_UNK&&ti!=t&&ti!=TY_ANY&&t!=TY_ANY){
          TYERR(e->args[i]->line,e->args[i]->col,"mixed element types in list literal: %s then %s",tyname(t),tyname(ti)); }
        if(t==TY_UNK) t=ti; }
      e->ty=TY_LIST; break; }
    case E_ID: {
      Var2*v=find_var2(e->s);
      if(!v){ SEMERR(e->line,e->col,"undefined variable '%s'",e->s); e->ty=TY_ANY; break; }
      e->ty=v->ty; e->struct_name=v->sname; break; }
    case E_NEG: { Type t=check_expr(e->a);
      if(t!=TY_NUM&&t!=TY_ANY&&t!=TY_UNK) TYERR(e->line,e->col,"unary '-' expects num, got %s",tyname(t));
      e->ty=TY_NUM; break; }
    case E_INDEX: {
      Type c=check_expr(e->a), i=check_expr(e->b);
      if(i!=TY_NUM&&i!=TY_ANY&&i!=TY_UNK) TYERR(e->b->line,e->b->col,"index expects num, got %s",tyname(i));
      if(c==TY_STR) e->ty=TY_NUM;
      else if(c==TY_LIST||c==TY_ANY) e->ty=TY_ANY;
      else { TYERR(e->line,e->col,"indexing requires str or list, got %s",tyname(c)); e->ty=TY_ANY; }
      break; }
    case E_NOT: { Type t=check_expr(e->a); (void)t; e->ty=TY_NUM; break; }
    case E_AND: case E_OR: { check_expr(e->a); check_expr(e->b); e->ty=TY_NUM; break; }
    case E_IFS: {
      check_expr(e->a); Type t=check_expr(e->b); Type f=check_expr(e->c);
      if(t!=f&&t!=TY_ANY&&f!=TY_ANY&&t!=TY_UNK&&f!=TY_UNK)
        TYERR(e->line,e->col,"conditional expression branches differ in type: %s vs %s",tyname(t),tyname(f));
      e->ty=(t==f)?t:TY_ANY; break; }
    case E_FIELD: {
      Type c=check_expr(e->a);
      if(c==TY_ANY){ e->ty=TY_ANY; break; }
      /* struct values are lists at runtime; the static struct type name is
         tracked per-variable (sname) and per-expression (structof). */
      char *sn=e->structof;
      if(!sn && e->a->k==E_ID) sn=e->a->struct_name;
      if(!sn){ TYERR(e->line,e->col,"field access '.%s' requires a struct value",e->s); e->ty=TY_ANY; break; }
      StructDef*S=find_struct(sn);
      if(!S){ TYERR(e->line,e->col,"unknown struct type '%s'",sn); e->ty=TY_ANY; break; }
      int fi=-1;
      for(int i=0;i<S->nfields;i++) if(!strcmp(S->fields[i],e->s)) fi=i;
      if(fi<0){ TYERR(e->line,e->col,"struct '%s' has no field '%s'",sn,e->s); e->ty=TY_ANY; break; }
      e->field=fi; e->ty=TY_ANY; break; }
    case E_STRUC: {
      StructDef*S=find_struct(e->s);
      if(!S){ SEMERR(e->line,e->col,"undefined struct '%s'",e->s); e->ty=TY_ANY; break; }
      if(e->nargs!=S->nfields){ SEMERR(e->line,e->col,"struct '%s' expects %d field(s), got %d",e->s,S->nfields,e->nargs); }
      for(int i=0;i<e->nargs;i++) check_expr(e->args[i]);
      e->ty=TY_LIST; e->structof=S->name; break; }
    case E_CALL: {
      int ar=builtin_arity(e->fn);
      if(ar!=-2){
        if(e->nargs!=ar) SEMERR(e->line,e->col,"builtin '%s' expects %d argument(s), got %d",e->fn,ar,e->nargs);
        for(int i=0;i<e->nargs;i++) check_expr(e->args[i]);
        if(!strcmp(e->fn,"concat")&&e->nargs==2){
          Type a=e->args[0]->ty,b=e->args[1]->ty;
          if(a==TY_LIST||b==TY_LIST) TYERR(e->line,e->col,"concat expects strings, got %s and %s",tyname(a),tyname(b));
        }
        if((!strcmp(e->fn,"len"))&&e->nargs==1){
          Type a=e->args[0]->ty;
          if(a==TY_NUM) TYERR(e->args[0]->line,e->args[0]->col,"len expects str or list, got num");
        }
        if(!strcmp(e->fn,"sx_index")&&e->nargs==2){
          Type a=e->args[0]->ty;
          if(a==TY_NUM) TYERR(e->args[0]->line,e->args[0]->col,"sx_index expects str or list, got num");
        }
        if(!strcmp(e->fn,"chr")&&e->nargs==1){
          Type a=e->args[0]->ty;
          if(a==TY_STR) TYERR(e->args[0]->line,e->args[0]->col,"chr expects num, got str");
        }
        e->ty=builtin_ret(e->fn); break;
      }
      Func*f=find_fn(e->fn);
      if(!f){ SEMERR(e->line,e->col,"undefined function '%s'",e->fn); e->ty=TY_ANY; break; }
      if(e->nargs!=f->nparams){ SEMERR(e->line,e->col,"function '%s' expects %d argument(s), got %d",e->fn,f->nparams,e->nargs); }
      for(int i=0;i<e->nargs;i++) check_expr(e->args[i]);
      e->ty=f->ret; break; }
    case E_BIN: {
      Type a=check_expr(e->a), b=check_expr(e->b);
      const char*op=e->s;
      if(!strcmp(op,"+")) e->ty=check_binop_plus(e,a,b);
      else if(!strcmp(op,"-")||!strcmp(op,"*")||!strcmp(op,"/")||!strcmp(op,"%")){
        if(a==TY_STR||b==TY_STR) TYERR(e->line,e->col,"operator '%s' does not accept str",op);
        if(a==TY_LIST||b==TY_LIST) TYERR(e->line,e->col,"operator '%s' does not accept list",op);
        e->ty=TY_NUM;
      } else if(!strcmp(op,"==")||!strcmp(op,"!=")){ e->ty=TY_NUM; }
      else {
        if(a==TY_LIST||b==TY_LIST) TYERR(e->line,e->col,"ordering comparison does not accept list");
        e->ty=TY_NUM;
      }
      break; }
  }
  return e->ty;
}
static void check_stmt(Stmt*s);
static void check_block_scoped(Block*b){
  int mark=nvars2; int save_depth=scope_depth; scope_depth++;
  for(int i=0;i<b->n;i++) check_stmt(b->items[i]);
  scope_depth=save_depth; nvars2=mark;
}
static void check_stmt(Stmt*s){
  GUARD();
  switch(s->k){
    case S_HOLD: { Type t=check_expr(s->e); declare_var(s->name,t,s->line,s->col,s->e->structof); break; }
    case S_ASSIGN: {
      Var2*v=find_var2(s->name);
      Type t=check_expr(s->e);
      if(!v){ SEMERR(s->line,s->col,"undefined variable '%s'; declare it first with 'hold %s = ...'",s->name,s->name); break; }
      redeclare_var(s->name,t,s->line,s->col,s->e->structof);
      break; }
    case S_SETIDX: {
      check_expr(s->e); check_expr(s->idx); check_expr(s->val);
      break; }
    case S_EXPR: check_expr(s->e); break;
    case S_ASSERT: check_expr(s->e); break;
    case S_SHOW: check_expr(s->e); break;
    case S_GIVE: {
      if(!cur_fn){ SEMERR(s->line,s->col,"'give' outside function"); s->give_ty=TY_NUM; break; }
      Type t=s->e?check_expr(s->e):TY_NUM;
      s->give_ty=t;
      cur_fn->has_give=1;
      if(cur_fn->ret==TY_UNK) cur_fn->ret=t==TY_UNK?TY_NUM:t;
      else if(t!=TY_UNK&&t!=cur_fn->ret&&t!=TY_ANY&&cur_fn->ret!=TY_ANY){
        TYERR(s->line,s->col,"function '%s' returns %s but this 'give' returns %s",cur_fn->name,tyname(cur_fn->ret),tyname(t));
      }
      break; }
    case S_WHEN: { check_expr(s->e); check_block_scoped(s->body); if(s->els) check_block_scoped(s->els); break; }
    case S_WHILE: { check_expr(s->e); check_block_scoped(s->body); break; }
  }
}
static void check_program(void){
  /* first pass: function signatures need bodies; iterate until stable */
  for(int iter=0;iter<8;iter++){
    int changed=0;
    /* functions */
    for(int i=0;i<nfuncs;i++){
      Func*f=&funcs[i];
      int mark=nvars2; int sd=scope_depth; scope_depth=0; cur_fn=f;
      for(int p=0;p<f->nparams;p++) declare_param(f->params[p],TY_ANY,1,1);
      Type rbefore=f->ret;
      for(int st=0;st<f->body->n;st++) check_stmt(f->body->items[st]);
      if(f->ret!=rbefore) changed=1;
      cur_fn=NULL; scope_depth=sd; nvars2=mark;
    }
    /* main */
    {
      int mark=nvars2; int sd=scope_depth; scope_depth=0; cur_fn=NULL;
      for(int st=0;st<main_block->n;st++) check_stmt(main_block->items[st]);
      scope_depth=sd; nvars2=mark;
    }
    if(!changed) break;
  }
}

/* ================= C backend ================= */
static FILE *out;
static int tmpc=0;
/* variable table for codegen: each declaration gets fresh slot name */
typedef struct { char *src; char *cname; int live; } CGVar;
static CGVar cgvars[MAXVARS]; static int ncgvars=0;
static CGVar*cg_find(const char*n){ for(int i=ncgvars-1;i>=0;i--) if(cgvars[i].live&&!strcmp(cgvars[i].src,n)) return &cgvars[i]; return NULL; }
static CGVar*cg_declare(const char*n){ /* always creates a fresh C slot (parameters) */
  char cname[64]; snprintf(cname,sizeof cname,"x%d",tmpc++);
  if(ncgvars>=MAXVARS){ fprintf(stderr,"codegen: too many variables\n"); exit(1); }
  cgvars[ncgvars].src=strdup(n); cgvars[ncgvars].cname=strdup(cname); cgvars[ncgvars].live=1;
  return &cgvars[ncgvars++];
}
static CGVar*cg_get_or_declare_first(const char*n,int *isfirst){
  CGVar*v=cg_find(n);
  if(v){ *isfirst=0; return v; }
  *isfirst=1; return cg_declare(n);
}

static void emit_num(double v){
  if(v==(long long)v && v<1e15 && v>-1e15) fprintf(out,"((double)%lldLL)",(long long)v);
  else fprintf(out,"((double)%a)",v);
}
static void emit_str_lit(const char*s){
  fputc('"',out);
  for(const unsigned char*p=(const unsigned char*)s;*p;p++){
    unsigned char c=*p;
    if(c=='"'||c=='\\') fprintf(out,"\\%c",c);
    else if(c=='\n') fputs("\\n",out);
    else if(c=='\t') fputs("\\t",out);
    else if(c=='\r') fputs("\\r",out);
    else if(c<32||c>=128) fprintf(out,"\\%03o",c);
    else fputc(c,out);
  }
  fputc('"',out);
}
static void emit_expr(Expr*e);
static void emit_stmt(Stmt*s,int indent);
static void emit_indent(int n){ for(int i=0;i<n;i++) fputs("  ",out); }

static void emit_call(Expr*e){
  int ar=builtin_arity(e->fn);
  if(ar!=-2){
    const char*bi="sx_b_unknown";
    if(!strcmp(e->fn,"len"))bi="sx_b_len"; else if(!strcmp(e->fn,"chr"))bi="sx_b_chr";
    else if(!strcmp(e->fn,"str"))bi="sx_b_str"; else if(!strcmp(e->fn,"concat"))bi="sx_b_concat";
    else if(!strcmp(e->fn,"sx_index"))bi="sx_index_v"; else if(!strcmp(e->fn,"read_file"))bi="sx_b_read_file";
    else if(!strcmp(e->fn,"write_file"))bi="sx_b_write_file"; else if(!strcmp(e->fn,"arg"))bi="sx_b_arg";
    else if(!strcmp(e->fn,"arg_count"))bi="sx_b_arg_count"; else if(!strcmp(e->fn,"string_eq"))bi="sx_b_string_eq";
    else if(!strcmp(e->fn,"list_new"))bi="sx_b_list_new"; else if(!strcmp(e->fn,"list_get"))bi="sx_b_list_get";
    else if(!strcmp(e->fn,"list_set"))bi="sx_b_list_set"; else if(!strcmp(e->fn,"push"))bi="sx_b_push";
    else if(!strcmp(e->fn,"type_of"))bi="sx_b_type_of"; else if(!strcmp(e->fn,"gc"))bi="sx_b_gc";
    fprintf(out,"%s(",bi);
    for(int i=0;i<e->nargs;i++){ if(i)fputs(",",out); emit_expr(e->args[i]); }
    fputc(')',out);
    return;
  }
  fprintf(out,"fn_%s(",e->fn);
  for(int i=0;i<e->nargs;i++){ if(i)fputs(",",out); emit_expr(e->args[i]); }
  fputc(')',out);
}
static void emit_expr(Expr*e){
  switch(e->k){
    case E_NU: emit_num(e->num); break;
    case E_NOT: fputs("sx_notb(sx_truthy(",out); emit_expr(e->a); fputs("))",out); break;
    case E_AND: fputs("(sx_truthy(",out); emit_expr(e->a); fputs(")?(",out); emit_expr(e->b); fputs("):0.0)",out); break;
    case E_OR: fputs("(sx_truthy(",out); emit_expr(e->a); fputs(")?1.0:(",out); emit_expr(e->b); fputs("))",out); break;
    case E_IFS: fputs("(sx_truthy(",out); emit_expr(e->a); fputs(")?(",out); emit_expr(e->b); fputs("):(",out); emit_expr(e->c); fputs("))",out); break;
    case E_STRUC: {
      fprintf(out,"sx_lit_list(%d",e->nargs);
      for(int i=0;i<e->nargs;i++){ fputs(",",out); emit_expr(e->args[i]); }
      fputc(')',out); break; }
    case E_FIELD: fputs("sx_index_v(",out); emit_expr(e->a); fprintf(out,",((double)%d))",e->field); break;
    case E_ST: fputs("sx_pack(sx_lit(",out); emit_str_lit(e->s); fputs("))",out); break;
    case E_ID: { CGVar*v=cg_find(e->s); fprintf(out,"%s",v?v->cname:"0.0"); break; }
    case E_LIST: {
      fprintf(out,"sx_lit_list(%d",e->nargs);
      /* helper takes count + variadic values */
      fprintf(out,",");
      for(int i=0;i<e->nargs;i++){ if(i)fputs(",",out); emit_expr(e->args[i]); }
      fputc(')',out); break; }
    case E_NEG: fputs("sx_neg(",out); emit_expr(e->a); fputc(')',out); break;
    case E_INDEX: fputs("sx_index_v(",out); emit_expr(e->a); fputs(",",out); emit_expr(e->b); fputc(')',out); break;
    case E_CALL: emit_call(e); break;
    case E_BIN: {
      const char*op=e->s;
      if(!strcmp(op,"+")) fputs("sx_add(",out);
      else if(!strcmp(op,"-")) fputs("sx_sub(",out);
      else if(!strcmp(op,"*")) fputs("sx_mul(",out);
      else if(!strcmp(op,"/")) fputs("sx_div(",out);
      else if(!strcmp(op,"%")) fputs("sx_modv(",out);
      else if(!strcmp(op,"&&")){ /* short-circuit */
        fputs("(sx_truthy(",out); emit_expr(e->a); fputs(")?(",out); emit_expr(e->b); fputs("):0.0)",out);
        break; }
      else if(!strcmp(op,"||")){
        fputs("(sx_truthy(",out); emit_expr(e->a); fputs(")?1.0:(",out); emit_expr(e->b); fputs("))",out);
        break; }
      else if(!strcmp(op,"==")) fputs("sx_eq(",out);
      else if(!strcmp(op,"!=")) fputs("sx_bool2d(1.0-sx_eq(",out);
      else if(!strcmp(op,"<")) fputs("sx_cmpnum(\"<\",",out);
      else if(!strcmp(op,"<=")) fputs("sx_cmpnum(\"<=\",",out);
      else if(!strcmp(op,">")) fputs("sx_cmpnum(\">\",",out);
      else if(!strcmp(op,">=")) fputs("sx_cmpnum(\">=\",",out);
      emit_expr(e->a); fputs(",",out); emit_expr(e->b);
      if(!strcmp(op,"!="))fputs("))",out); else fputs(")",out);
      break; }
  }
}
static void emit_block(Block*b,int indent){
  int mark=ncgvars;
  for(int i=0;i<b->n;i++) emit_stmt(b->items[i],indent);
  /* drop locals created in this block (reverse order = inner first) */
  while(ncgvars>mark){
    ncgvars--;
    emit_indent(indent); fprintf(out,"sx_var_drop(&%s);\n",cgvars[ncgvars].cname);
  }
}
static void emit_stmt(Stmt*s,int indent){
  switch(s->k){
    case S_HOLD: {
      int first=0;
      CGVar*v=cg_get_or_declare_first(s->name,&first);
      if(first){ emit_indent(indent); fprintf(out,"double %s=0.0;\n",v->cname); }
      emit_indent(indent); fprintf(out,"sx_assign(&%s,",v->cname); emit_expr(s->e); fputs(");\n",out);
      return; }
    case S_SHOW: emit_indent(indent); fputs("sx_show(",out); emit_expr(s->e); fputs(");\n",out); return;
    case S_ASSERT: emit_indent(indent); fputs("sx_assert(",out); emit_expr(s->e); fprintf(out,",%d,%d);\n",s->line,s->col); return;
    case S_EXPR: emit_indent(indent); emit_expr(s->e); fputs(";\n",out); return;
    case S_ASSIGN: {
      CGVar*v=cg_find(s->name);
      if(!v){ fprintf(stderr,"codegen: undefined variable %s\n",s->name); exit(1); }
      emit_indent(indent); fprintf(out,"sx_assign(&%s,",v->cname); emit_expr(s->e); fputs(");\n",out); return; }
    case S_SETIDX: {
      CGVar*v=cg_find(s->name);
      if(!v){ fprintf(stderr,"codegen: undefined variable %s\n",s->name); exit(1); }
      emit_indent(indent); fprintf(out,"sx_setidx(&%s,",v->cname); emit_expr(s->idx); fputs(",",out); emit_expr(s->val); fputs(");\n",out); return; }
    case S_GIVE: emit_indent(indent); fputs("return ",out); if(s->e) emit_expr(s->e); else fputs("0.0",out); fputs(";\n",out); return;
    case S_WHEN: {
      emit_indent(indent); fputs("if(sx_truthy(",out); emit_expr(s->e); fputs(")){\n",out);
      emit_block(s->body,indent+1); emit_indent(indent); fputs("}\n",out);
      if(s->els){ emit_indent(indent); fputs("else {\n",out); emit_block(s->els,indent+1); emit_indent(indent); fputs("}\n",out); }
      return; }
    case S_WHILE: {
      emit_indent(indent); fputs("while(sx_truthy(",out); emit_expr(s->e); fputs(")){\n",out);
      emit_block(s->body,indent+1); emit_indent(indent); fputs("}\n",out);
      return; }
  }
}

static void emit_function(Func*f){
  ncgvars=0; tmpc=0;
  fprintf(out,"static double fn_%s(",f->name);
  for(int p=0;p<f->nparams;p++) fprintf(out,"double a%d%s",p,p+1<f->nparams?", ":"");
  if(f->nparams==0) fputs("void",out);
  fputs("){\n",out);
  for(int p=0;p<f->nparams;p++){
    char an[64]; snprintf(an,sizeof an,"%s",f->params[p]);
    CGVar*v=cg_declare(an);
    fprintf(out,"  double %s=sx_retain_copy(a%d);\n",v->cname,p);
  }
  emit_block(f->body,1);
  fprintf(out,"  return sx_n(0);\n}\n\n");
}
/* runtime helpers emitted into generated C */
static void emit_prologue(void){
  fputs("#include \"sx_runtime.h\"\n\n",out);
  fputs("static double sx_retain_copy(double v){int k=sx_kind(v);"
        "if(k==1)sx_retain_s((char*)sx_upack(v));else if(k==2)sx_list_retain(sx_upack(v));return v;}\n",out);
  fputs("static double sx_neg(double v){int k=sx_kind(v);if(k!=0){fprintf(stderr,\"sx: unary - on non-num\\n\");exit(1);}return -v;}\n",out);
  fputs("static double sx_sub(double a,double b){if(sx_kind(a)||sx_kind(b)){fprintf(stderr,\"sx: '-' on non-num\\n\");exit(1);}return a-b;}\n",out);
  fputs("static double sx_mul(double a,double b){if(sx_kind(a)||sx_kind(b)){fprintf(stderr,\"sx: '*' on non-num\\n\");exit(1);}return a*b;}\n",out);
  fputs("static double sx_div(double a,double b){if(sx_kind(a)||sx_kind(b)){fprintf(stderr,\"sx: '/' on non-num\\n\");exit(1);}if(b==0){fprintf(stderr,\"sx: division by zero\\n\");exit(1);}return a/b;}\n",out);
  fputs("static double sx_notb(double v){return v?0.0:1.0;}\n",out);
  fputs("#define SX_AND(a,b) (sx_truthy(a)?(sx_truthy(b)?1.0:0.0):0.0)\n",out);
  fputs("#define SX_OR(a,b) (sx_truthy(a)?1.0:(sx_truthy(b)?1.0:0.0))\n",out);
  fputs("static void sx_assert(double v,int line,int col){ if(!sx_truthy(v)){ fprintf(stderr,\"assertion failed at %d:%d\\n\",line,col); exit(1);} }\n",out);
  fputs("static void sx_setidx(double*p,double i,double val){ int k=sx_kind(*p);\n",out);
  fputs("  if(k==2){ SxList*L=(SxList*)sx_upack(*p); long idx=(long)i;\n",out);
  fputs("    if(idx<0||idx>=(long)L->n){fprintf(stderr,\"sx: list index out of range on assignment\\n\");exit(1);}\n",out);
  fputs("    L->v[idx]=sx_retain_copy(val); return; }\n",out);
  fputs("  fprintf(stderr,\"sx: subscript assignment requires a list\\n\"); exit(1); }\n",out);
  fputs("static double sx_lit_list(int n,...){va_list ap;va_start(ap,n);SxList*L=sx_list_alloc((size_t)n);for(int i=0;i<n;i++)L->v[L->n++]=va_arg(ap,double);va_end(ap);return sx_pack(L);}\n",out);
  fputs("\n",out);
}

/* ================= module loader ================= */
#define MAXMOD 256
static char *modseen[MAXMOD]; static int nmod=0;
static int seen_mod(const char*p){ for(int i=0;i<nmod;i++) if(!strcmp(modseen[i],p)) return 1; return 0; }
static char *slurp(const char*p,long*sz){
  FILE*f=fopen(p,"rb"); if(!f) return NULL;
  fseek(f,0,SEEK_END); long n=ftell(f); fseek(f,0,SEEK_SET);
  char*b=malloc((size_t)n+1); size_t rd=fread(b,1,(size_t)n,f); b[rd]=0; fclose(f);
  if(sz){ *sz=(long)rd; }
  return b;
}
/* Replace every top-level `import "path" ...` line with the (recursively
   spliced) module source, or with a same-length comment when the module was
   already loaded (duplicate-import cache). Detects cycles and rejects
   absolute paths / traversal. */
static char *splice_src(char*src,const char*base,int depth,char**cycle_stack){
  size_t outcap=strlen(src)+4096; char*out=malloc(outcap); size_t ol=0; out[0]=0;
  char *lines_copy=strdup(src);
  char *line=lines_copy;
  while(line){
    char *nl=strchr(line,'\n'); if(nl)*nl=0;
    char *q=line; while(*q==' '||*q=='\t')q++;
    int is_import=!strncmp(q,"import",6)&&(q[6]==' '||q[6]=='"'||q[6]=='\t');
    int handled=0;
    if(is_import&&depth<32){
      char *p0=strchr(q,'"');
      if(p0){ char *p1=strchr(p0+1,'"');
        if(p1){
          handled=1;
          char *rel=strndup(p0+1,(size_t)(p1-p0-1));
          if(rel[0]=='/'||strstr(rel,"..")){
            fprintf(stderr,"sxc_seed: invalid module path '%s' (absolute paths and '..' traversal are not allowed)\n",rel);
            exit(1);
          }
          char joined[4096]; snprintf(joined,sizeof joined,"%s/%s",base,rel);
          char *canon=realpath(joined,NULL);
          if(!canon){ fprintf(stderr,"sxc_seed: cannot resolve module '%s' (from directory %s)\n",rel,base); exit(1); }
          for(int i=0;i<depth;i++) if(cycle_stack[i]&&!strcmp(cycle_stack[i],canon)){
            fprintf(stderr,"sxc_seed: cyclic module import detected:");
            for(int j=i;j<depth;j++) fprintf(stderr," %s",cycle_stack[j]);
            fprintf(stderr," -> %s\n",canon); exit(1);
          }
          cycle_stack[depth]=canon;
          if(!seen_mod(canon)){
            if(nmod<MAXMOD) modseen[nmod++]=strdup(canon);
            char *mdir=strdup(canon); char*slash=strrchr(mdir,'/'); if(slash)*slash=0; else strcpy(mdir,".");
            char *msrc=slurp(canon,NULL);
            if(!msrc){ fprintf(stderr,"sxc_seed: cannot read module %s\n",canon); exit(1); }
            char *spliced=splice_src(msrc,mdir,depth+1,cycle_stack);
            size_t ml=strlen(spliced);
            while(ol+ml+2>outcap){ outcap=(outcap+ml)*2+16; out=realloc(out,outcap); }
            memcpy(out+ol,spliced,ml); ol+=ml; out[ol++]='\n'; out[ol]=0;
            free(msrc);
          }
          cycle_stack[depth]=NULL;
          free(rel); free(canon);
        }
      }
    }
    if(!handled){
      size_t ll=strlen(line);
      while(ol+ll+2>outcap){ outcap*=2; out=realloc(out,outcap); }
      memcpy(out+ol,line,ll); ol+=ll; out[ol++]='\n'; out[ol]=0;
    } else {
      /* keep one blank line so later line numbers stay stable per module */
      while(ol+2>outcap){ outcap*=2; out=realloc(out,outcap); }
      out[ol++]='\n'; out[ol]=0;
    }
    line=nl?nl+1:NULL;
  }
  free(lines_copy);
  return out;
}

int main(int argc,char**argv){
  const char *in=NULL;
  for(int i=1;i<argc;i++){
    if(!strcmp(argv[i],"--emit-ir")) { /* handled after parse */ continue; }
    if(argv[i][0]!='-') { in=argv[i]; break; }
  }
  if(!in){ fprintf(stderr,"usage: sxc_seed [--emit-ir] <file.sa>\n"); return 1; }
  g_main_path=in;
  char *raw=slurp(in,NULL);
  if(!raw){ fprintf(stderr,"sxc_seed: cannot read %s\n",in); return 1; }
  char *dir=strdup(in); char*slash=strrchr(dir,'/'); if(slash)*slash=0; else strcpy(dir,".");
  char **cyc=malloc(sizeof(char*)*33); memset(cyc,0,sizeof(char*)*33);
  cyc[0]=strdup(in);
  char *src=splice_src(raw,dir,1,cyc);
  index_lines(src);
  tokenize(src);
  main_block=newb();
  skip_nl();
  while(!at(T_END)){
    if(at(T_EOFT)){ adv(); continue; }
    p_stmt_into(main_block);
    skip_nl();
  }
  check_program();
  if(g_errors){ fprintf(stderr,"sxc_seed: %d error(s)\n",g_errors); return 1; }
  if(getenv("SX_EMIT_IR")){
    /* textual IR dump (backend-independent; see docs/IR.md) */
    printf("# Sayanox IR v1\n");
    for(int i=0;i<nfuncs;i++){
      Func*f=&funcs[i];
      printf("func %s/%d -> %s {\n",f->name,f->nparams,tyname(f->ret));
      printf("}\n");
    }
    printf("entry {\n");
    for(int i=0;i<main_block->n;i++){
      Stmt*s=main_block->items[i];
      switch(s->k){
        case S_HOLD: printf("  hold %s <- expr@%d:%d [%s]\n",s->name,s->e?s->e->line:0,s->e?s->e->col:0,s->e?tyname(s->e->ty):"?"); break;
        case S_SHOW: printf("  show expr@%d:%d [%s]\n",s->e->line,s->e->col,tyname(s->e->ty)); break;
        case S_WHEN: printf("  when expr@%d:%d { ... }\n",s->e->line,s->e->col); break;
        case S_WHILE: printf("  while expr@%d:%d { ... }\n",s->e->line,s->e->col); break;
        case S_GIVE: printf("  give\n"); break;
        default: printf("  stmt@%d:%d\n",s->line,s->col); break;
      }
    }
    printf("}\n");
    return 0;
  }
  out=stdout;
  emit_prologue();
  for(int i=0;i<nfuncs;i++) emit_function(&funcs[i]);
  ncgvars=0; tmpc=0;
  fputs("int main(int argc,char**argv){ sx_boot(argc,argv);\n",out);
  emit_block(main_block,1);
  fputs("  sx_cleanup(); return 0;\n}\n",out);
  return 0;
}
