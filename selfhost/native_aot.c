/* Sayanox native AOT — real Linux x86-64 machine code (no clang, no C).
 *
 * Covers the pure-min dialect:
 *   hold / show / when / else / while
 *   ints: + - * / % , == != < <= > >= , parentheses, unary -
 *   lists: [1, 2, 3], xs[i], len(xs), push(xs, v), show xs -> [list len=N]
 *   strings: "lit", concat, len, sx_index, chr, read_file, write_file,
 *            arg, arg_count, string_eq (sx_eq),
 *            s == t / s != t (strcmp semantics), show of strings
 *            (string + number is rejected, as in seed-min and gen2)
 *   structs: struct S { f, g }; S { x: 3, y: "a" } literals (labels or
 *            positional, declaration order, every field filled); nesting
 *            any depth (inner declared first); p.x / l.a.x chains;
 *            copies (hold m = l.b, hold r = q)
 *   functions: make f(a, b) { ... give EXPR }, recursion, numbers only,
 *              top-level definitions only; hold inside a body is a clear
 *              error (a local would live in the data segment, shared by
 *              every recursive call)
 *   modules: use "file.sa" (spliced before parsing, depth <= 8; a missing
 *              file or an unquoted path is a hard error)
 *
 * Anything outside this is a hard error with a clear message — the
 * backend never emits silently wrong code.
 *
 * ABI: globals live in a data segment (r12 = data base, set in every
 * prologue). The heap is a bump allocator (r_malloc) over lazily `mmap`ped
 * 64 KiB chunks and never frees anything (GC.md, "Native AOT and the
 * seeds"); r_malloc rounds to 8 bytes and exits with `out of memory` when
 * mmap fails. Strings are NUL-terminated.
 * sx_list = { long n; long cap; long *d; }. Function args go in
 * rdi rsi rdx rcx r8 r9 (ints, <= 6). give = return; a function that
 * falls off returns 0.
 *
 * Scratch policy: the left operand of a binary operator, the base of an
 * index expression and every staged call argument are held on the machine
 * stack (push/pop) across the sub-emit, so they survive nested calls,
 * including recursion; r15 = short-lived temp; r14 = saved data-scratch
 * across a literal; r11 = literal fill temp; [r12+OFF_SCR] = current
 * literal base. Runtime helpers preserve r12 (and every callee-saved
 * register); user functions use an rbp frame and never touch r13-r15.
 *
 * Usage: native_aot in.sa out
 */
#include <ctype.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <stdarg.h>
#include <unistd.h>

#define CMAX 524288
#define DMAX 262144
#define BASE 0x400000ULL
#define NSLOT 64
#define MAXS 32
#define MAXF 64
#define MAXFD 16
#define MAXP 6

static unsigned char code[CMAX]; static size_t cn;
static unsigned char data[DMAX]; static size_t dn;

/* ---- data layout (offsets from the data VA) ---- */
#define OFF_CUR   0   /* heap cursor (u64)  */
#define OFF_END   24  /* end of heap chunk  */
#define OFF_ARGV  8   /* char **argv        */
#define OFF_ARGC  16  /* long argc          */
#define OFF_SCR   32  /* 8-byte scratch     */
                      /* (must NOT alias OFF_END: store_scr() writes here on
                         every literal, and OFF_END is the heap chunk end) */
static size_t d_glob; /* globals array      */
static size_t d_err_div, d_err_list, d_err_str, d_err_malloc;
static size_t d_list1, d_list2, d_nl, d_empty;
static size_t d_pow;    /* 309 doubles 1e0..1e308 (number formatting) */
static size_t d_numbuf; /* 64-byte buffer: `show <number>` formats here, no heap */

/* ================= x86-64 mini encoder ================= */
#define AX 0
#define CX 1
#define DX 2
#define BX 3
#define SP 4
#define BP 5
#define SI 6
#define DI 7

static void e1(unsigned char b){ if(cn>=CMAX){fprintf(stderr,"native_aot: code OOM\n");exit(1);} code[cn++]=b; }
static void e32(uint32_t v){ e1(v); e1(v>>8); e1(v>>16); e1(v>>24); }
static void e64(uint64_t v){ for(int i=0;i<8;i++) e1((unsigned char)(v>>(8*i))); }
static void erel32(size_t at,size_t to){ int32_t d=(int32_t)(to-(at+6)); memcpy(code+at+2,&d,4); }
static void erel32j(size_t at,size_t to){ int32_t d=(int32_t)(to-(at+5)); memcpy(code+at+1,&d,4); } /* for 5-byte jmp */

static void rexb(int W,int R,int X,int B){
  if(W||R||X||B){ uint8_t b=0x40; if(W)b|=8; if(R)b|=4; if(X)b|=2; if(B)b|=1; e1(b); }
}
/* disp: -1 = none; otherwise a real displacement (disp8 if |v|<=127).
 * idx: -1 = none, else 0-15.  scale 0-3 (powers of two). */
static void emit_modrm(int reg,int rm,int scale,int idx,int disp){
  /* SIB is required when the base field is rsp (bits 100, incl. r12) or
     whenever an index register is present.  mod: 00=no disp (disp32 only
     in the rip / rsp-base special cases we never emit), 01=disp8,
     10=disp32.  Getting the mod field right is mandatory: a mod01
     ModRM consumes exactly one displacement byte. */
  int need_sib = ((rm&7)==4)||(idx>=0);
  int m;
  if(disp==-1) m=0;
  else if(disp>=-128&&disp<=127) m=1;
  else m=2;
  e1((uint8_t)((m<<6)|((reg&7)<<3)|(need_sib?4:(rm&7))));  /* REX.R carries bit 3 */
  if(need_sib){
    int ii = (idx>=0) ? idx : 4;
    e1((uint8_t)((scale<<6)|((ii&7)<<3)|(rm&7)));  /* index field is 3 bits; REX.X extends */
  }
  if(disp!=-1){
    if(m==1) e1((unsigned char)(int8_t)disp);
    else e32((uint32_t)(int32_t)disp);
  }
}
static void mv_rr(int d,int s){ rexb(1, s>7, 0, d>7); e1(0x89); e1((uint8_t)(0xC0|(s<<3)|(d&7))); }
static void mv_m64(int base,int idx,int scale,int disp,int s){
  rexb(1, s>7, idx>7, base>7); e1(0x89); emit_modrm(s, base, scale, idx, disp);
}
static void mv_r64m(int d,int base,int idx,int scale,int disp){
  rexb(1, d>7, idx>7, base>7); e1(0x8b); emit_modrm(d, base, scale, idx, disp);
}
static void lea_rm(int d,int base,int idx,int scale,int disp){
  rexb(1, d>7, idx>7, base>7); e1(0x8d); emit_modrm(d, base, scale, idx, disp);
}
static void mov_imm64(int r,uint64_t v){ rexb(1, 0, 0, r>7); e1((uint8_t)(0xb8+(r&7))); e64(v); } /* B8+rd: r8-r15 via REX.B (gas: 49 b8) */
static void mov_imm8m(int base,int idx,int scale,int disp,uint8_t v){
  rexb(0, 0, idx>7, base>7); e1(0xc6); emit_modrm(0, base, scale, idx, disp); e1(v);
}
static void mvz_rm(int d,int base,int idx,int scale,int disp){ /* movzx r32, byte [mem] */
  rexb(0, d>7, idx>7, base>7); e1(0x0f); e1(0xb6); emit_modrm(d&7, base, scale, idx, disp);
}
static void bin_rr(int op,int d,int s){ rexb(1, s>7, 0, d>7); e1((uint8_t)op); e1((uint8_t)(0xC0|(s<<3)|(d&7))); }
static void bin_imm8(int op,int r,uint8_t v){ rexb(1, 0, 0, r>7); e1(0x83); e1((uint8_t)(0xC0|(op<<3)|(r&7))); e1(v); }
static void bin_imm32(int op,int r,uint32_t v){ rexb(1, 0, 0, r>7); e1(0x81); e1((uint8_t)(0xC0|(op<<3)|(r&7))); e32(v); }
static void fm7(int sub,int r){ rexb(1, 0, 0, r>7); e1(0xf7); e1((uint8_t)(0xC0|(sub<<3)|(r&7))); }
static void test_rr(int a,int b){ rexb(1, b>7, 0, a>7); e1(0x85); e1((uint8_t)(0xC0|(b<<3)|(a&7))); }
static void xor_rr(int a,int b){ rexb(1, b>7, 0, a>7); e1(0x31); e1((uint8_t)(0xC0|(b<<3)|(a&7))); }
static void incdec_r(int inc,int r){ rexb(1, 0, 0, r>7); e1(0xff); e1((uint8_t)(0xC0|((inc?0:1)<<3)|(r&7))); }
static void inc_mem_r(int r){ rexb(1,0,0,r>7); e1(0xff); e1((uint8_t)(0x40|(r&7))); e1(0x00); } /* inc [r] (disp8=0) */
static void push_r(int r){ if(r>7) e1(0x49); e1((uint8_t)(0x50+(r&7))); }
static void pop_r(int r){ if(r>7) e1(0x49); e1((uint8_t)(0x58+(r&7))); }
static void jcc_rel32(int c,int32_t d){ e1(0x0f); e1((uint8_t)(0x80+c)); e32((uint32_t)d); }
static void jmp_rel32(int32_t d){ e1(0xe9); e32((uint32_t)d); }
static void setcc(int c,int r){ rexb(0, 0, 0, r>7); e1(0x0f); e1((uint8_t)(0x90+c)); e1((uint8_t)(0xC0|(r&7))); }
static void movzx_al_to_rax(void){ rexb(1,0,0,0); e1(0x0f); e1(0xb6); e1(0xc0); }
static void sar_imm(int r,int v){ rexb(1, 0, 0, r>7); e1(0xc1); e1((uint8_t)(0xC0|(7<<3)|(r&7))); e1((uint8_t)v); }
static void shl_imm(int r,int v){ rexb(1, 0, 0, r>7); e1(0xc1); e1((uint8_t)(0xC0|(4<<3)|(r&7))); e1((uint8_t)v); }  /* env gas: SHL = C1 /4 */
static void shr_imm(int r,int v){ rexb(1, 0, 0, r>7); e1(0xc1); e1((uint8_t)(0xC0|(5<<3)|(r&7))); e1((uint8_t)v); }  /* env gas: SHR = C1 /5 */

/* ---- SSE2 scalar double (register-direct forms only; xmm0-xmm7) ----
 * Numbers are IEEE doubles held as raw bits in the same 64-bit slots and
 * registers that used to hold integers; arithmetic moves them into xmm0/xmm1.
 * Encoding: [prefix] [REX] 0F op ModRM(11 reg rm).  Verified with objdump. */
static void sse_rr(int pfx,int op,int W,int reg,int rm){
  e1((uint8_t)pfx); rexb(W, reg>7, 0, rm>7); e1(0x0f); e1((uint8_t)op);
  e1((uint8_t)(0xC0|((reg&7)<<3)|(rm&7)));
}
static void movq_xr(int x,int r){ sse_rr(0x66,0x6e,1,x,r); }   /* movq xmm, r64 */
static void movq_rx(int r,int x){ sse_rr(0x66,0x7e,1,x,r); }   /* movq r64, xmm */
static void addsd(int a,int b){ sse_rr(0xf2,0x58,0,a,b); }
static void mulsd(int a,int b){ sse_rr(0xf2,0x59,0,a,b); }
static void subsd(int a,int b){ sse_rr(0xf2,0x5c,0,a,b); }
static void divsd(int a,int b){ sse_rr(0xf2,0x5e,0,a,b); }
static void ucomisd(int a,int b){ sse_rr(0x66,0x2e,0,a,b); }
static void cvtsi2sd(int x,int r){ sse_rr(0xf2,0x2a,1,x,r); }  /* xmm = (double)r64 */
static void cvttsd2si(int r,int x){ sse_rr(0xf2,0x2c,1,r,x); } /* r64 = (long)xmm, truncating */
static void cvtsd2si(int r,int x){ sse_rr(0xf2,0x2d,1,r,x); }  /* r64 = round-to-nearest-even */
/* rax (double bits) -> rax (long, truncated toward zero, like C's cast) */
static void emit_d2i(void){ movq_xr(0,0); cvttsd2si(0,0); }
/* rax (long) -> rax (double bits) */
static void emit_i2d(void){ cvtsi2sd(0,0); movq_rx(0,0); }

/* ---- tiny forward/backward label system for hand-written runtime code ---- */
#define MAXLBL 96
static long lbl_pos[MAXLBL]; static int nlbl;
static size_t lbl_fix[MAXLBL][24]; static int lbl_fixw[MAXLBL][24]; static int lbl_nfix[MAXLBL];
static int L_new(void){
  if(nlbl>=MAXLBL){ fprintf(stderr,"native_aot: too many labels\n"); exit(1); }
  lbl_pos[nlbl]=-1; lbl_nfix[nlbl]=0; return nlbl++;
}
static void L_patch(size_t at,int w,size_t to){
  int32_t d=(int32_t)((long)to-(long)(at+(size_t)w)); memcpy(code+at+(size_t)w-4,&d,4);
}
static void L_bind(int l){
  lbl_pos[l]=(long)cn;
  for(int i=0;i<lbl_nfix[l];i++) L_patch(lbl_fix[l][i],lbl_fixw[l][i],cn);
  lbl_nfix[l]=0;
}
static void L_ref(int l,size_t at,int w){
  if(lbl_pos[l]>=0){ L_patch(at,w,(size_t)lbl_pos[l]); return; }
  if(lbl_nfix[l]>=24){ fprintf(stderr,"native_aot: too many label refs\n"); exit(1); }
  lbl_fix[l][lbl_nfix[l]]=at; lbl_fixw[l][lbl_nfix[l]]=w; lbl_nfix[l]++;
}
static void J_cc(int c,int l){ size_t at=cn; e1(0x0f); e1((uint8_t)(0x80+c)); e32(0); L_ref(l,at,6); }
static void J_mp(int l){ size_t at=cn; e1(0xe9); e32(0); L_ref(l,at,5); }
static void stb_rdi(uint8_t v){ e1(0xc6); e1(0x07); e1(v); }  /* mov byte [rdi], imm8 */
static void stal_rdi(void){ e1(0x88); e1(0x07); }              /* mov [rdi], al */
/* condition codes for 0F 80+c (jcc) and 0F 90+c (setcc) — same numbering */
#define JC_B 2      /* <  / setb */
#define JC_NBE 3    /* >= / setae */
#define JC_Z 4      /* == / sete */
#define JC_NZ 5     /* != / setne */
#define JC_L 12     /* signed <  (setl / jl) */
#define JC_LE 14    /* signed <= (setle / jle) */
#define JC_G 15     /* signed >  (jg; no setg - negate setle) */
#define JC_GE 13    /* signed >= (setge / jge) */
#define JC_JS 8     /* signed < 0 (jcc only) */
#define JC_JNS 9    /* signed >= 0 (jcc only) */

/* ---------------- patches ---------------- */
enum { PFN=0, PBUILTIN=1 };
static struct { size_t at; int kind; int idx; } patch_call[8192]; static int npc;
static struct { size_t at; } patch_r12[4096]; static int npr;
static void call_p(int kind,int idx){
  e1(0xe8);
  if(npc>=8192){ fprintf(stderr,"native_aot: OOM patches\n"); exit(1); }
  patch_call[npc].at=cn; patch_call[npc].kind=kind; patch_call[npc].idx=idx; npc++;
  e32(0);
}
#define callf(i) call_p(PFN,i)
#define callb(i) call_p(PBUILTIN,i)
static void lea_r12_data(void){
  /* lea r12, [rip+disp32]: REX.WR 8D 25 disp32 (mod00 reg100 rm101) */
  rexb(1, 1, 0, 0); e1(0x8d); e1(0x25);
  if(npr>=4096){ fprintf(stderr,"native_aot: OOM patches\n"); exit(1); }
  patch_r12[npr].at=cn; npr++; e32(0);
}

/* ---------------- data ---------------- */
static size_t d_alloc(size_t n){
  dn = (dn+7)&~(size_t)7;
  if(n>DMAX||dn+n>DMAX){ fprintf(stderr,"native_aot: data OOM\n"); exit(1); }
  size_t at=dn; memset(data+dn,0,n); dn+=n; return at;
}
static size_t d_str(const char*s){ size_t n=strlen(s); size_t at=d_alloc(n+1); memcpy(data+at,s,n); return at; }

/* ---------------- text utilities ---------------- */
static void sw(const char**p){ while(**p&&isspace((unsigned char)**p)) (*p)++; }
static int id0(char c){ return isalpha((unsigned char)c)||c=='_'; }
static int idc(char c){ return isalnum((unsigned char)c)||c=='_'; }
/* gen2-only full-language statements: name them and stop, at every pass.
   Without this, `for c in s { show c }` died in the type-inference pre-pass
   as "undefined variable 'c'" before the statement walker could say what the
   real problem was. */
static void errx(const char*fmt,...);
static void reject_fullang(const char*p){
  char w[16]; int i=0;
  if(!id0(*p)) return;
  while(idc(*p)&&i+1<16) w[i++]=*p++; w[i]=0;
  if(!strcmp(w,"for")||!strcmp(w,"break")||!strcmp(w,"continue")||!strcmp(w,"elif"))
    errx("'%s' is a full-language statement and not in the native subset (native speaks the pure-min statements; use selfhost/gen2)",w,NULL);
}
static int mkw(const char**p,const char*k){ size_t n=strlen(k); if(strncmp(*p,k,n)||idc((*p)[n])) return 0; *p+=n; return 1; }
static int pid(const char**p,char*b,size_t c){
  sw(p); if(!id0(**p)) return 0;
  size_t i=0; while(idc(**p)&&i+1<c) b[i++]=*(*p)++; b[i]=0; return 1;
}
static void errx(const char*fmt,...);
/* number literal: digits, optionally `.digits` (2.5).  A '.' is only part
   of the number when a digit follows; `2.` / `2.x` / `1.5.3` are errors
   (seed-min and gen2 reject them too).  Value parsed by strtod. */
static int pnum(const char**p,double*o){
  sw(p); if(!isdigit((unsigned char)**p)) return 0;
  const char*s0=*p; char buf[64]; size_t i=0;
  while(isdigit((unsigned char)**p)) (*p)++;
  if(**p=='.'){
    if(!isdigit((unsigned char)(*p)[1])) errx("malformed number literal (a '.' must be followed by digits)");
    (*p)++;
    while(isdigit((unsigned char)**p)) (*p)++;
  }
  if(**p=='.'||id0(**p)) errx("malformed number literal");
  for(const char*q=s0;q<*p&&i+1<sizeof buf;q++) buf[i++]=*q;
  buf[i]=0; *o=strtod(buf,NULL); return 1;
}
static uint64_t dbits(double d){ uint64_t u; memcpy(&u,&d,8); return u; }
static int pstr(const char**p,char*buf,size_t cap,size_t*len){
  sw(p); if(**p!='"') return 0; (*p)++; size_t i=0;
  while(**p&&**p!='"'){
    char c=*(*p)++;
    if(c=='\\'&&**p){ char x=*(*p)++; if(x=='n')c='\n'; else if(x=='t')c='\t'; else c=x; }
    if(i+1<cap) buf[i++]=c;
  }
  if(**p=='"') (*p)++;
  buf[i]=0; *len=i; return 1;
}

static void errx(const char*fmt,...){
  va_list ap;
  fprintf(stderr,"native_aot: ");
  va_start(ap,fmt);
  vfprintf(stderr,fmt,ap);
  va_end(ap);
  fputc('\n',stderr); exit(1);
}
static int is_builtin(const char*n);
static int f_find(const char*n);
static int g_find(const char*n);
static void endstmt(const char**p){
  sw(p);
  if(!**p||**p=='}') return;
  if(**p=='/'&&(*p)[1]=='/') return;
  const char*r=*p;
  if(mkw(&r,"hold")||mkw(&r,"show")||mkw(&r,"when")||mkw(&r,"while")||
     mkw(&r,"make")||mkw(&r,"give")||mkw(&r,"struct")||mkw(&r,"otherwise")||mkw(&r,"else")){ return; }
  if(id0(*r)){
    char w[64]; int i=0;
    while(idc(*r)&&i+1<64) w[i++]=*r++; w[i]=0;
    if(!strcmp(w,"for")||!strcmp(w,"break")||!strcmp(w,"continue")||!strcmp(w,"elif"))
      errx("'%s' is a full-language statement and not in the native subset (native speaks the pure-min statements; use selfhost/gen2)",w,NULL);
    sw(&r);
    if(*r=='='&&(g_find(w)>=0)) return;                /* next line is an assignment */
    if(*r=='('&&!strcmp(w,"push")) return;             /* next line is a call statement (push only, as in seed-min/gen2) */
  }
  errx("unexpected token after statement (expected end of line or next statement)",*p,NULL);
}

/* ---------------- tables ---------------- */
typedef enum { K_NUM=0, K_STR=1, K_LIST=2, K_STRUCT=3 } kind_t;
#define K_UNK (-1)

typedef struct { char name[64]; int kind; int sid; } Glob;
typedef struct { char name[64]; int kind; int sid; } Field;
typedef struct { char name[64]; Field f[MAXFD]; int nf; } SDef;
typedef struct { char name[64]; char params[MAXP][64]; int nparam; int start; } Fn;

static Glob G[NSLOT]; static int nG;
static SDef S[MAXS]; static int nS;
static Fn  F[MAXF]; static int nF;

static int g_find(const char*n){ for(int i=0;i<nG;i++) if(!strcmp(G[i].name,n)) return i; return -1; }
static int g_decl(const char*n){
  int i=g_find(n); if(i>=0) return i;
  if(nG>=NSLOT){ fprintf(stderr,"native_aot: too many globals (native limit: %d)\n",NSLOT); exit(1); }
  snprintf(G[nG].name,64,"%s",n); G[nG].kind=K_UNK; G[nG].sid=-1; return nG++;
}
static int s_find(const char*n){ for(int i=0;i<nS;i++) if(!strcmp(S[i].name,n)) return i; return -1; }
static int s_field(int sid,const char*n){ for(int i=0;i<S[sid].nf;i++) if(!strcmp(S[sid].f[i].name,n)) return i; return -1; }
static int f_find(const char*n){ for(int i=0;i<nF;i++) if(!strcmp(F[i].name,n)) return i; return -1; }
static int is_builtin(const char*n){
  return !strcmp(n,"concat")||!strcmp(n,"len")||!strcmp(n,"chr")||!strcmp(n,"sx_index")||
         !strcmp(n,"index")||!strcmp(n,"read_file")||!strcmp(n,"write_file")||
         !strcmp(n,"arg")||!strcmp(n,"arg_count")||!strcmp(n,"string_eq")||
         !strcmp(n,"sx_eq")||!strcmp(n,"push");
}
static const char*kname(int k){
  if(k==K_NUM) return "a number";
  if(k==K_STR) return "a string";
  if(k==K_LIST) return "a list";
  if(k==K_STRUCT) return "a struct";
  return "an unknown type";
}

/* ================= use expansion (before any parsing) ================= */
static char*rf(const char*p,size_t*n){
  FILE*f=fopen(p,"rb");
  if(!f){ fprintf(stderr,"native_aot: cannot open use file: %s\n",p); exit(1); }
  fseek(f,0,SEEK_END); long N=ftell(f); fseek(f,0,SEEK_SET);
  char*b=malloc((size_t)N+1);
  if(fread(b,1,(size_t)N,f)!=(size_t)N){ fprintf(stderr,"native_aot: read error: %s\n",p); exit(1); }
  b[N]=0; fclose(f); *n=(size_t)N; return b;
}
static char*expand_use(const char*src,size_t sn,const char*dir,int depth){
  if(depth>8){ fprintf(stderr,"native_aot: use nesting deeper than 8\n"); exit(1); }
  /* The buffer MUST grow: a spliced file can be arbitrarily larger than the
     including one (the old fixed sn*2+64KB overflowed the heap on any use of
     a big library). */
  size_t cap=sn+65536, o=0;
  char*out=malloc(cap);
  if(!out){ fprintf(stderr,"native_aot: out of memory\n"); exit(1); }
#define EU_NEED(nbytes) do{ if(o+(nbytes)+1>cap){ \
    while(o+(nbytes)+1>cap) cap*=2; \
    char*tmp=realloc(out,cap); \
    if(!tmp){ fprintf(stderr,"native_aot: out of memory\n"); exit(1); } \
    out=tmp; } }while(0)
  size_t i=0;
  while(i<=sn){
    size_t ls=i; while(i<=sn&&src[i]!='\n') i++;
    size_t le=i; if(i<=sn) i++;
    const char*q=src+ls;
    while(q<src+le&&isspace((unsigned char)*q)) q++;
    if(q<src+le&&q[0]=='/'&&q[1]=='/'){ EU_NEED(le-ls+1); memcpy(out+o,src+ls,le-ls+1); o+=le-ls+1; continue; }
    const char*r=q;
    if(mkw(&r,"use")){
      const char*w=r; sw(&w);
      if(*w!='"'){ fprintf(stderr,"native_aot: use needs a quoted path: use \"file.sa\"\n"); exit(1); }
      {
        const char*pe=w+1; while(*pe&&*pe!='"') pe++;
        if(*pe!='"'){ fprintf(stderr,"native_aot: unterminated use path\n"); exit(1); }
        char path[1024]; size_t pl=(size_t)(pe-w-1); if(pl>=1024) pl=1023;
        memcpy(path,w+1,pl); path[pl]=0;
        char cand1[2048],cand2[2048];
        if(dir&&dir[0]) snprintf(cand1,sizeof cand1,"%s/%s",dir,path); else snprintf(cand1,sizeof cand1,"%s",path);
        snprintf(cand2,sizeof cand2,"%s",path);
        char*body=NULL; size_t bn=0;
        if(access(cand1,R_OK)==0) body=rf(cand1,&bn);
        else if(access(cand2,R_OK)==0) body=rf(cand2,&bn);
        if(!body){ fprintf(stderr,"native_aot: cannot open use file: %s\n",path); exit(1); }
        char*sub=expand_use(body,bn,dir,depth+1);
        free(body);
        size_t sl=strlen(sub);
        EU_NEED(sl+1);
        memcpy(out+o,sub,sl); o+=sl;
        free(sub);
        if(le<sn){ EU_NEED(1); out[o++]='\n'; }
        continue;
      }
    }
    EU_NEED(le-ls+1);
    memcpy(out+o,src+ls,le-ls+1); o+=le-ls+1;
  }
  out[o]=0;
#undef EU_NEED
  return out;
}

/* ================= statement skipping (string/comment/brace aware) ================= */
static const char*skip_stmt(const char*p){
  sw(&p);
  if(mkw(&p,"hold")||mkw(&p,"show")||mkw(&p,"give")||mkw(&p,"use")){
    while(*p&&*p!='\n') p++;
    return p;
  }
  /* only block statements own a { ... }: a call statement such as
     `push(xs, 7)` used to scan ahead to the NEXT block in the file and skip
     everything up to its }, so type inference never saw the statements in
     between ("undefined variable" for a later hold) */
  { const char*r=p;
    if(!(mkw(&r,"when")||mkw(&r,"while")||mkw(&r,"make")||mkw(&r,"struct")||
         mkw(&r,"otherwise")||mkw(&r,"else"))){
      while(*p&&*p!='\n') p++;
      return p;
    }
  }
  const char*q=p; int inq=0;
  while(*q){
    if(inq){ if(*q=='\\') q++; else if(*q=='"') inq=0; q++; continue; }
    if(*q=='"'){ inq=1; q++; continue; }
    if(*q=='{'){
      int d=1; q++;
      while(*q){
        if(inq){ if(*q=='\\') q++; else if(*q=='"') inq=0; q++; continue; }
        if(*q=='"'){ inq=1; q++; continue; }
        if(*q=='{') d++;
        else if(*q=='}'){ d--; if(d==0){ q++; return q; } }
        q++;
      }
      return q;
    }
    q++;
  }
  while(*p&&*p!='\n') p++;
  return p;
}

/* ================= phase 1: collect definitions ================= */
static void collect_defs(const char*src){
  const char*p=src;
  while(*p){
    const char*line=p; sw(&p);
    if(!*p) break;
    if(p[0]=='/'&&p[1]=='/'){ while(*p&&*p!='\n') p++; continue; }
    if(mkw(&p,"struct")){
      char nm[64];
      if(!pid(&p,nm,64)){ fprintf(stderr,"native_aot: struct needs a name\n"); exit(1); }
      if(s_find(nm)>=0){ fprintf(stderr,"native_aot: struct '%s' declared twice\n",nm); exit(1); }
      if(nS>=MAXS){ fprintf(stderr,"native_aot: too many structs (native limit: %d)\n",MAXS); exit(1); }
      strcpy(S[nS].name,nm); S[nS].nf=0;
      sw(&p);
      if(*p!='{'){ fprintf(stderr,"native_aot: struct %s needs { fields }\n",nm); exit(1); }
      p++;
      const char*q=p; int inq=0;
      while(*q){
        if(inq){ if(*q=='\\') q++; else if(*q=='"') inq=0; q++; continue; }
        if(*q=='"'){ inq=1; q++; continue; }
        if(*q=='/'&&q[1]=='/'){ while(*q&&*q!='\n') q++; continue; }
        if(*q=='}') break;
        if(id0(*q)){
          char fd[64]; int i=0;
          while(idc(*q)&&i+1<64) fd[i++]=*q++;
          fd[i]=0;
          if(S[nS].nf>=MAXFD){ fprintf(stderr,"native_aot: struct '%s' has more than %d fields\n",nm,MAXFD); exit(1); }
          strcpy(S[nS].f[S[nS].nf].name,fd);
          S[nS].f[S[nS].nf].kind=K_UNK; S[nS].f[S[nS].nf].sid=-1;
          S[nS].nf++;
          continue;
        }
        q++;
      }
      if(*q!='}'){ fprintf(stderr,"native_aot: struct %s: missing }\n",nm); exit(1); }
      nS++;
      p=skip_stmt(line);
    }
    else if(mkw(&p,"make")){
      char nm[64];
      if(!pid(&p,nm,64)){ fprintf(stderr,"native_aot: make needs a name\n"); exit(1); }
      if(f_find(nm)>=0){ fprintf(stderr,"native_aot: function '%s' declared twice\n",nm); exit(1); }
      if(nF>=MAXF){ fprintf(stderr,"native_aot: too many functions (native limit: %d)\n",MAXF); exit(1); }
      strcpy(F[nF].name,nm); F[nF].nparam=0; F[nF].start=-1;
      sw(&p);
      if(*p=='<'){ fprintf(stderr,"native_aot: make %s<...>: generics are not in the native subset (gen2 monomorphises make NAME<T>); native has no generic functions\n",nm); exit(1); }
      if(*p!='('){ fprintf(stderr,"native_aot: make %s: expected (params)\n",nm); exit(1); }
      p++;
      for(;;){
        sw(&p);
        if(*p==')'){ p++; break; }
        char pm[64];
        if(!pid(&p,pm,64)){ fprintf(stderr,"native_aot: make %s: bad param list\n",nm); exit(1); }
        if(F[nF].nparam>=MAXP){ fprintf(stderr,"native_aot: make %s: at most %d params\n",nm,MAXP); exit(1); }
        strcpy(F[nF].params[F[nF].nparam++],pm);
        sw(&p);
        if(*p==','){ p++; continue; }
        if(*p==')'){ p++; break; }
        fprintf(stderr,"native_aot: make %s: bad param list\n",nm); exit(1);
      }
      nF++;
      p=skip_stmt(line);
    }
    else if(mkw(&p,"hold")){
      char nm[64];
      if(!pid(&p,nm,64)){ fprintf(stderr,"native_aot: hold needs a name\n"); exit(1); }
      g_decl(nm);
      p=skip_stmt(line);
    }
    else p=skip_stmt(line); /* show/when/while/give: nothing to collect */
  }
}

/* ================= phase 2: kind inference (no codegen) =================
 * pk_* walks the same grammar as the emit phase and returns a kind.
 * K_UNK propagates until the fixpoint; PKX_K/PKX_S carry the kind and
 * (for structs) the struct id of the value just parsed. */
static int PKX_K=K_NUM, PKX_S=-1;
static int fkind_seen[MAXS][MAXFD], fkind_val[MAXS][MAXFD], fsid_val[MAXS][MAXFD];
/* While the kind inference fixpoint runs, a field chain that is not resolved
   *yet* is normal (the struct table is only filled in one level per round), so
   it must come back as K_UNK instead of aborting.  The final validation scan
   and the emit phase run with pk_soft=0 and still report every real error. */
static int pk_soft=0;

static int pk_prim(const char**p,int depth);
static int pk_post(const char**p,int depth);
static int pk_term(const char**p,int depth);
static int pk_rel(const char**p,int depth);
static int pk_full(const char**p,int depth);

static int pk_prim(const char**p,int depth){
  sw(p);
  if(depth>32) errx("expression too deep");
  if(**p=='['){
    (*p)++;
    for(;;){
      sw(p);
      if(**p==']'){ (*p)++; break; }
      int k=pk_rel(p,depth+1);
      if(k!=K_NUM) errx("list elements must be numbers");
      sw(p);
      if(**p==','){ (*p)++; continue; }
      if(**p==']'){ (*p)++; break; }
      errx("list literal needs , or ]");
    }
    PKX_K=K_LIST; PKX_S=-1;
    return K_LIST;
  }
  if(**p=='"'){
    char buf[512]; size_t l;
    if(!pstr(p,buf,sizeof buf,&l)) errx("unterminated string");
    PKX_K=K_STR; PKX_S=-1;
    return K_STR;
  }
  if(**p=='('){
    (*p)++;
    /* the full expression grammar, comparisons included -- emission uses
       emit_expr here, and `(a > 1) + 1` used to fail with "expected )" */
    int k=pk_full(p,depth+1);
    sw(p);
    if(**p!=')') errx("expected )");
    (*p)++;
    PKX_K=k; PKX_S=(k==K_STRUCT)?PKX_S:-1;
    return k;
  }
  if(**p=='-'){
    (*p)++;
    int k=pk_prim(p,depth+1);
    if(k!=K_NUM) errx("unary - on a non-number");
    PKX_K=K_NUM; PKX_S=-1;
    return K_NUM;
  }
  double v;
  if(pnum(p,&v)){ PKX_K=K_NUM; PKX_S=-1; return K_NUM; }
  char n[64];
  if(pid(p,n,64)){
    const char*q=*p; sw(&q);
    /* `name {` is a struct literal unless name is a variable and not a
       struct: `while n {` / `when x {` use a bare variable as the condition */
    if(*q=='{'&&(s_find(n)>=0||g_find(n)<0)){
      int sid=s_find(n);
      if(sid<0) errx("unknown struct '%s'",n,NULL);
      (*p)=q; (*p)++;
      int nf=S[sid].nf, cnt=0;
      for(;;){
        sw(p);
        if(**p=='}'){ (*p)++; break; }
        char lb[64]; int lbl=0;
        const char*q2=*p;
        if(id0(*q2)){
          char tmp[64]; int i=0; const char*r3=q2;
          while(idc(*r3)&&i+1<64) tmp[i++]=*r3++; tmp[i]=0;
          const char*q4=r3; sw(&q4);
          if(*q4==':'){ lbl=1; strcpy(lb,tmp); *p=q4; (*p)++; }
        }
        int fi;
        if(lbl){
          if(cnt>=nf) errx("too many fields in struct '%s' literal",n,NULL);
          fi=s_field(sid,lb);
          if(fi<0) errx("no field '%s' in struct '%s'",lb,n);
          if(fi!=cnt) errx("struct '%s' literal fields must be given in declaration order",n,NULL);
        } else {
          if(cnt>=nf) errx("too many fields in struct '%s' literal",n,NULL);
          fi=cnt;
        }
        int k=pk_rel(p,depth+1);
        if(k==K_STRUCT&&PKX_S<0) k=K_UNK;
        /* the shared dialect (seed-min and gen2) rejects a list inside a
           struct field and a struct nested from a later declaration; native
           must not accept a program the other two reject. */
        if(k==K_LIST)
          errx("struct '%s' field '%s' cannot hold a list (seed-min/gen2 reject this)",S[sid].name,S[sid].f[fi].name);
        if(k==K_STRUCT&&PKX_S>=sid)
          errx("struct '%s' nests struct '%s' declared later; declare the nested struct first",S[sid].name,S[PKX_S].name);
        if(fkind_seen[sid][fi]){
          if(fkind_val[sid][fi]!=k)
            errx("struct field '%s.%s' is used with two different types",S[sid].name,S[sid].f[fi].name);
          if(k==K_STRUCT&&fsid_val[sid][fi]>=0&&PKX_S>=0&&fsid_val[sid][fi]!=PKX_S)
            errx("struct field '%s.%s' is used with two different struct types",S[sid].name,S[sid].f[fi].name);
        } else if(k>=0){
          fkind_seen[sid][fi]=1; fkind_val[sid][fi]=k;
          fsid_val[sid][fi]=(k==K_STRUCT)?PKX_S:-1;
        }
        cnt++;
        sw(p);
        if(**p==','){ (*p)++; continue; }
        if(**p=='}'){ (*p)++; break; }
        errx("struct literal needs , or }");
      }
      if(cnt!=nf) errx("struct '%s' literal must fill every field (%d expected, %d given)",n,nf,cnt);
      PKX_K=K_STRUCT; PKX_S=sid;
      return K_STRUCT;
    }
    if(*q=='('){
      if(is_builtin(n)){
        (*p)=q; (*p)++;
        int nargs=0;
        for(;;){
          sw(p);
          if(**p==')'){ (*p)++; break; }
          (void)pk_rel(p,depth+1);
          nargs++;
          sw(p);
          if(**p==','){ (*p)++; continue; }
          if(**p==')'){ (*p)++; break; }
          errx("call needs , or )");
        }
        static const struct { const char*nn; int a; } ar[] = {
          {"concat",2},{"len",1},{"chr",1},{"sx_index",2},{"index",2},{"read_file",1},
          {"write_file",2},{"arg",1},{"arg_count",0},{"string_eq",2},{"sx_eq",2},{"push",2}
        };
        for(int i=0;i<(int)(sizeof ar/sizeof ar[0]);i++)
          if(!strcmp(n,ar[i].nn)){
            if(nargs!=ar[i].a) errx("%s takes %d args, got %d",n,ar[i].a,nargs);
            if(!strcmp(n,"concat")||!strcmp(n,"chr")||!strcmp(n,"read_file")||!strcmp(n,"arg")){ PKX_K=K_STR; PKX_S=-1; return K_STR; }
            if(!strcmp(n,"push")){ PKX_K=K_LIST; PKX_S=-1; return K_LIST; }
            PKX_K=K_NUM; PKX_S=-1; return K_NUM;
          }
      }
      int fi=f_find(n);
      if(fi>=0){
        (*p)=q; (*p)++;
        int nargs=0;
        for(;;){
          sw(p);
          if(**p==')'){ (*p)++; break; }
          int k=pk_rel(p,depth+1);
          if(k!=K_NUM) errx("function '%s' takes numbers (arg %d is not a number)",n,nargs+1);
          nargs++;
          sw(p);
          if(**p==','){ (*p)++; continue; }
          if(**p==')'){ (*p)++; break; }
          errx("call needs , or )");
        }
        if(nargs!=F[fi].nparam) errx("function '%s' takes %d args, got %d",n,F[fi].nparam,nargs);
        PKX_K=K_NUM; PKX_S=-1;
        return K_NUM;
      }
    }
    int gi=g_find(n);
    if(gi<0) errx("undefined variable '%s' (hold it first)",n,NULL);
    int k=G[gi].kind;
    if(k==K_STRUCT&&G[gi].sid<0) k=K_UNK;
    PKX_K=k; PKX_S=(k==K_STRUCT)?G[gi].sid:-1;
    return k;
  }
  errx("bad expression (expected a number, string, list, name)");
  return K_UNK;
}
/* primary + postfix ([index] / .field) chains.  Split out of pk_term so the
   right operand of * / % may carry a postfix too (p.x * p.x, 2 * xs[1]);
   + - already parsed their right side as a full term, so `p.x + p.y` worked
   while `p.x * p.y` died with "* is numeric-only". */
static int pk_post(const char**p,int depth){
  int k=pk_prim(p,depth);
  for(;;){
    const char*q=*p; sw(&q);
    if(*q=='['){
      if(k!=K_LIST&&k!=K_STR) errx("cannot index a %s",kname(k));
      (*p)=q; (*p)++;
      int ik=pk_rel(p,depth+1);
      if(ik!=K_NUM) errx("index must be a number");
      sw(p);
      if(**p!=']') errx("expected ]");
      (*p)++;
      k=K_NUM;
      continue;
    }
    if(*q=='.'){
      if(k!=K_STRUCT){
        if(!pk_soft) errx("cannot access a field of a %s",kname(k));
        PKX_K=K_UNK; PKX_S=-1;
      }
      (*p)=q; (*p)++;
      char fn[64];
      if(!pid(p,fn,64)) errx("expected a field name after .");
      int sid=PKX_S;
      if(k!=K_STRUCT||sid<0){
        /* unknown so far: consume the field name and keep K_UNK (soft) or
           report it (hard) */
        if(!pk_soft) errx("cannot resolve the struct type here");
        k=K_UNK; PKX_S=-1; continue;
      }
      int fi=s_field(sid,fn);
      if(fi<0){
        if(!pk_soft) errx("no field '%s' in struct '%s'",fn,S[sid].name);
        k=K_UNK; PKX_S=-1; continue;
      }
      int fk=S[sid].f[fi].kind;
      if(fk==K_STRUCT&&S[sid].f[fi].sid<0) fk=K_UNK;
      k=fk;
      /* the field may itself be a struct: carry its id so that the next
         `.name` in a chain (l.a.x) resolves against the inner struct, not
         against the outer one.  Without this, `l.a.x` looked up `x` in
         `Line` and was rejected. */
      PKX_S=(fk==K_STRUCT)?S[sid].f[fi].sid:-1;
      continue;
    }
    break;
  }
  PKX_K=k; PKX_S=(k==K_STRUCT)?PKX_S:-1;
  return k;
}
static int pk_term(const char**p,int depth){
  int k=pk_post(p,depth);
  for(;;){
    sw(p); char op=**p;
    if(op!='*'&&op!='/'&&op!='%') break;
    if(op=='/'&&(*p)[1]=='/') break;   /* a // comment on the next line, not a division */
    (*p)++;
    int k2=pk_post(p,depth);
    if(k!=K_NUM||k2!=K_NUM) errx("%c is numeric-only",op);
    k=K_NUM;
  }
  PKX_K=k; PKX_S=(k==K_STRUCT)?PKX_S:-1;
  return k;
}
static int pk_rel(const char**p,int depth){
  int k=pk_term(p,depth);
  for(;;){
    sw(p); char op=**p;
    if(op!='+'&&op!='-') break;
    (*p)++;
    int k2=pk_term(p,depth);
    if(op=='-'){
      if(k!=K_NUM||k2!=K_NUM) errx("- is numeric-only");
      k=K_NUM;
    } else {
      if(k==K_STR||k2==K_STR){
        if(k==K_UNK||k2==K_UNK) k=K_UNK;
        else if(k==K_STR&&k2==K_STR) k=K_STR;
        /* seed-min and gen2 both reject a string joined to a number, so the
           shared pure-min subset rejects it here too (it used to be accepted
           and silently rendered the number with %g) */
        else errx("+ joins two strings or adds two numbers (a string + a number is not in the pure-min subset)");
      } else {
        if(k!=K_NUM||k2!=K_NUM) errx("+ is for numbers or strings");
        k=K_NUM;
      }
    }
  }
  PKX_K=k; PKX_S=(k==K_STRUCT)?PKX_S:-1;
  return k;
}
static int pk_full(const char**p,int depth){
  int k=pk_rel(p,depth);
  sw(p);
  char c0=**p,c1=(*p)[1];
  int is2=0; const char*op=NULL;
  if(c0=='='&&c1=='='){ is2=1; op="=="; }
  else if(c0=='!'&&c1=='='){ is2=1; op="!="; }
  else if(c0=='<'&&c1=='='){ is2=1; op="<="; }
  else if(c0=='>'&&c1=='='){ is2=1; op=">="; }
  else if(c0=='<'){ is2=0; op="<"; }
  else if(c0=='>'){ is2=0; op=">"; }
  if(op){
    *p += is2? 2 : 1;
    int k2=pk_rel(p,depth);
    if(k==K_STR&&k2!=K_STR) errx("string compared with a non-string");
    if(k==K_STR&&(c0=='<'||c0=='>')) errx("string comparison with '%s' is not in the native subset (native has string_eq for ==/!=; string ordering runs on seed-min and gen2)",op);
    if(k==K_LIST||k==K_STRUCT||k2==K_LIST||k2==K_STRUCT)
      errx("cannot compare %s with %s",kname(k),kname(k2));
    PKX_K=K_NUM; PKX_S=-1;
    return K_NUM;
  }
  return k;
}

static int infer_round(const char*src){
  int changed=0;
  const char*p=src;
  while(*p){
    const char*line=p; sw(&p);
    if(!*p) break;
    if(p[0]=='/'&&p[1]=='/'){ while(*p&&*p!='\n') p++; continue; }
    const char*end=skip_stmt(line);
    const char*rp=line; sw(&rp);
    reject_fullang(rp);
    if(mkw(&rp,"hold")){
      char nm[64];
      if(pid(&rp,nm,64)){
        sw(&rp);
        if(*rp=='='){
          rp++;
          int k=pk_full(&rp,0);
          int gi=g_decl(nm);
          if(k>=0){
            if(G[gi].kind==K_UNK){ G[gi].kind=k; G[gi].sid=(k==K_STRUCT)?PKX_S:-1; changed=1; }
            else if(G[gi].kind!=k)
              errx("variable '%s' is used with two different types (%s and %s)",nm,kname(k),kname(G[gi].kind));
            else if(G[gi].kind==K_STRUCT&&G[gi].sid<0&&PKX_S>=0){ G[gi].sid=PKX_S; changed=1; }
          }
        }
      }
    }
    p=end;
  }
  return changed;
}
/* copy the field kinds learned so far into the struct table; returns 1 when
   anything changed.  Published after every round (not only at the end) so a
   chain such as r.q.p.x resolves one `.field` per round. */
static int infer_publish(void){
  int changed=0;
  for(int s=0;s<nS;s++) for(int f=0;f<S[s].nf;f++){
    int k=K_NUM, sid=-1;
    if(fkind_seen[s][f]){
      k=fkind_val[s][f];
      sid=(k==K_STRUCT)?fsid_val[s][f]:-1;
    }
    if(S[s].f[f].kind!=k){ S[s].f[f].kind=k; changed=1; }
    if(S[s].f[f].sid!=sid){ S[s].f[f].sid=sid; changed=1; }
  }
  return changed;
}
static void infer(const char*src){
  pk_soft=1;
  for(int round=0;round<16;round++){
    int changed=infer_round(src);
    changed|=infer_publish();
    if(!changed) break;
  }
  pk_soft=0;
  const char*p=src;
  while(*p){
    const char*line=p; sw(&p);
    if(!*p) break;
    if(p[0]=='/'&&p[1]=='/'){ while(*p&&*p!='\n') p++; continue; }
    const char*end=skip_stmt(line);
    const char*rp=line; sw(&rp);
    if(mkw(&rp,"show")){
      int k=pk_full(&rp,0);
      if(k==K_UNK) errx("cannot infer the type of the show value");
    } else if(mkw(&rp,"when")||mkw(&rp,"while")){
      int k=pk_full(&rp,0);
      if(k==K_UNK) errx("cannot infer the type of the condition (it must be a number)");
      if(k!=K_NUM) errx("condition must be a number (got %s)",kname(k));
    } else if(mkw(&rp,"give")){
      int k=pk_full(&rp,0);
      if(k==K_UNK) errx("cannot infer the type of the give value");
      if(k!=K_NUM) errx("give must give a number (got %s)",kname(k));
    } else {
      char w[64]; const char*r2=rp; int wi=0;
      while(idc(*r2)&&wi+1<64) w[wi++]=*r2++; w[wi]=0;
      const char*r3=r2; sw(&r3);
      if(wi>0&&*r3=='('&&!strcmp(w,"push")){
        (void)pk_full(&rp,0);
      } else if(wi>0&&*r3=='='){
        int gi=g_find(w);
        if(gi<0) errx("cannot assign to \"%s\" (hold it first)",w,NULL);
        rp++;
        int k=pk_full(&rp,0);
        if(k==K_UNK) errx("cannot infer the type of the assignment value");
        if(G[gi].kind==K_UNK){ G[gi].kind=k; G[gi].sid=(k==K_STRUCT)?-1:-1; }
        else if(G[gi].kind!=k) errx("variable '%s' is used with two different types",w,NULL);
      }
    }
    p=end;
  }
  for(int i=0;i<nG;i++)
    if(G[i].kind==K_UNK)
      errx("cannot infer the type of variable '%s'",G[i].name,NULL);
}

/* ================= phase 3: emit ================= */
static int XK=K_NUM, XS=-1;     /* kind / struct id of the value in rax */
static int cur_fn=-1;           /* -1 = top level */
static size_t builtin_off[32];
/* argument registers, System V AMD64: rdi rsi rdx rcx r8 r9 */
static const int argreg[MAXP]={DI,SI,DX,CX,8,9};

enum { B_MALLOC,B_STRLEN,B_CMPSTR,B_CONCAT,B_N2STR,B_PUTSTR,B_WCSTR,B_ITONO,B_ITOWRITE,
       B_SHOWLIST,B_MLIST,B_LGET,B_LLEN,B_LPUSH,B_SGET,B_CHR,B_READFILE,B_WRITEFILE,
       B_ARG,B_ARGC,B_DIE,B_NFMT,B_SHOWNUM };

static void emit_prim(const char**p,int depth);
static void emit_post(const char**p,int depth);
static void emit_term(const char**p,int depth);
static void emit_rel(const char**p,int depth);
static void emit_expr(const char**p,int depth);
static void emit_prog(const char**p,int in_fn,int stop);
static void emit_fn(int fi,const char**p);
static void emit_call_builtin(const char**p,const char*n,int depth);

static void load_global(int gi){ mv_r64m(AX,12,-1,0,(int)(d_glob+8*(size_t)gi)); }
static void store_global(int gi){ mv_m64(12,-1,0,(int)(d_glob+8*(size_t)gi),AX); }
static void load_param(int i){ mv_r64m(AX,BP,-1,0,-8*(i+1)); }
static void store_scr(void){ mv_m64(12,-1,0,OFF_SCR,AX); }
static void load_scr(void){ mv_r64m(AX,12,-1,0,OFF_SCR); }
static void save_scr(int r){ mv_m64(12,-1,0,OFF_SCR,r); }
static void load_scr_r(int r){ mv_r64m(r,12,-1,0,OFF_SCR); }

/* literal helpers: the enclosing literal is pushed on the machine stack.
   r14 alone is not enough -- a nested builtin call (concat) clobbers it, and
   with three levels of nesting the grandparent was lost, so the inner block
   was stored into the wrong struct (r.q.p.x read a pointer, not a number).
   [r12+OFF_SCR] holds the literal currently being built. */
static void lit_begin(void){ mv_r64m(14,12,-1,0,OFF_SCR); push_r(14); }
static void lit_end(void){ load_scr(); pop_r(14); save_scr(14); } /* rax = this literal; outer scratch back */

/* ---- primary ---- */
static void emit_prim(const char**p,int depth){
  sw(p);
  if(depth>32) errx("expression too deep");
  if(**p=='['){
    const char*q=*p; q++;
    int n=0;
    for(;;){
      sw(&q);
      if(*q==']'){ q++; break; }
      (void)pk_rel(&q,0);
      n++;
      sw(&q);
      if(*q==','){ q++; continue; }
      if(*q==']'){ q++; break; }
      errx("list literal needs , or ]");
    }
    (*p)++;                       /* consume '[' (counting used lookahead q) */
    if(n==0){ sw(p); if(**p!=']') errx("list literal needs ]"); (*p)++; }
    lit_begin();
    mov_imm64(AX,(uint64_t)(uint32_t)n);
    callb(B_MLIST);
    store_scr();
    for(int i=0;i<n;i++){
      sw(p);
      emit_expr(p,depth+1);
      if(XK!=K_NUM) errx("list elements must be numbers");
      mv_rr(11,AX);
      load_scr();
      mv_m64(AX,-1,0,24+8*i,11);
      sw(p);
      if(i+1<n){
        if(**p!=',') errx("list literal needs , or ]");
        (*p)++;
      } else {
        if(**p!=']') errx("list literal needs , or ]");
        (*p)++;
      }
    }
    lit_end();
    XK=K_LIST; XS=-1;
    return;
  }
  if(**p=='"'){
    char buf[512]; size_t l;
    if(!pstr(p,buf,sizeof buf,&l)) errx("unterminated string");
    size_t off=d_str(buf);
    lea_rm(AX,12,-1,0,(int)off);
    XK=K_STR; XS=-1;
    return;
  }
  if(**p=='('){
    (*p)++;
    emit_expr(p,depth+1);
    sw(p);
    if(**p!=')') errx("expected )");
    (*p)++;
    return;
  }
  if(**p=='-'){
    (*p)++;
    emit_prim(p,depth+1);
    if(XK!=K_NUM) errx("unary - on a non-number");
    /* 0.0 - x (not a sign-bit flip: -(0) prints 0 like C's 0 - 0.0) */
    movq_xr(1,AX); xor_rr(AX,AX); movq_xr(0,AX); subsd(0,1); movq_rx(AX,0);
    return;
  }
  double v;
  if(pnum(p,&v)){ mov_imm64(AX,dbits(v)); XK=K_NUM; XS=-1; return; }
  char n[64];
  if(pid(p,n,64)){
    if(cur_fn>=0){
      for(int i=0;i<F[cur_fn].nparam;i++)
        if(!strcmp(F[cur_fn].params[i],n)){ load_param(i); XK=K_NUM; XS=-1; return; }
    }
    const char*q=*p; sw(&q);
    /* `name {` is a struct literal unless name is a variable and not a
       struct: `while n {` / `when x {` use a bare variable as the condition */
    if(*q=='{'&&(s_find(n)>=0||g_find(n)<0)){
      int sid=s_find(n);
      if(sid<0) errx("unknown struct '%s'",n,NULL);
      (*p)=q; (*p)++;
      int nf=S[sid].nf;
      lit_begin();
      mov_imm64(AX,(uint64_t)(uint32_t)(8*nf));
      mv_rr(DI,AX);
      callb(B_MALLOC);
      store_scr();
      int cnt=0;
      for(;;){
        sw(p);
        if(**p=='}') break;
        char lb[64]; int lbl=0;
        const char*q2=*p;
        if(id0(*q2)){
          char tmp[64]; int i=0; const char*r3=q2;
          while(idc(*r3)&&i+1<64) tmp[i++]=*r3++; tmp[i]=0;
          const char*q4=r3; sw(&q4);
          if(*q4==':'){ lbl=1; strcpy(lb,tmp); *p=q4; (*p)++; }
        }
        int fi;
        if(lbl){
          if(cnt>=nf) errx("too many fields in struct '%s' literal",n,NULL);
          fi=s_field(sid,lb);
          if(fi<0) errx("no field '%s' in struct '%s'",lb,n);
          if(fi!=cnt) errx("struct '%s' literal fields must be given in declaration order",n,NULL);
        } else {
          if(cnt>=nf) errx("too many fields in struct '%s' literal",n,NULL);
          fi=cnt;
        }
        emit_expr(p,depth+1);
        if(XK==K_LIST)
          errx("struct '%s' field '%s' cannot hold a list (seed-min/gen2 reject this)",S[sid].name,S[sid].f[cnt].name);
        if(XK==K_STRUCT&&XS>=sid)
          errx("struct '%s' nests struct '%s' declared later; declare the nested struct first",S[sid].name,S[XS].name);
        if(S[sid].f[cnt].kind!=XK)
          errx("struct field '%s.%s' is used with two different types",S[sid].name,S[sid].f[cnt].name);
        mv_rr(11,AX);
        load_scr();
        lea_rm(AX,AX,-1,0,8*cnt);
        mv_m64(AX,-1,0,0,11);
        cnt++;
        sw(p);
        if(**p==','){ (*p)++; continue; }
        if(**p=='}'){ (*p)++; break; }
        errx("struct literal needs , or }");
      }
      if(cnt!=nf) errx("struct '%s' literal must fill every field (%d expected, %d given)",n,nf,cnt);
      lit_end();
      XK=K_STRUCT; XS=sid;
      return;
    }
    if(*q=='('){
      if(is_builtin(n)){ emit_call_builtin(p,n,depth); return; }
      int fi=f_find(n);
      if(fi>=0){
        (*p)=q; (*p)++;
        int nargs=0;
        for(;;){
          sw(p);
          if(**p==')'){ (*p)++; break; }
          emit_expr(p,depth+1);
          if(XK!=K_NUM) errx("function '%s' takes numbers (arg %d is %s)",n,nargs+1,kname(XK));
          /* every evaluated arg goes on the machine stack: a LATER arg may
             itself be a call (user function, or a builtin whose malloc maps
             a fresh chunk), which clobbers the arg registers -- staging in
             rdi/rsi/... while parsing used to corrupt earlier args. */
          push_r(AX);
          nargs++;
          sw(p);
          if(**p==','){ (*p)++; continue; }
          if(**p==')'){ (*p)++; break; }
          errx("call needs , or )");
        }
        if(nargs!=F[fi].nparam) errx("function '%s' takes %d args, got %d",n,F[fi].nparam,nargs);
        /* pop into the arg registers, last pushed first (pop only writes its
           own register, so no staged arg can be clobbered) */
        for(int i=nargs-1;i>=0;i--) pop_r(argreg[i]);
        callf(fi);
        XK=K_NUM; XS=-1;
        return;
      }
    }
    int gi=g_find(n);
    if(gi<0) errx("undefined variable '%s' (hold it first)",n,NULL);
    if(G[gi].kind==K_UNK) errx("undefined variable '%s' (hold it first)",n,NULL);
    load_global(gi);
    XK=G[gi].kind; XS=(G[gi].kind==K_STRUCT)?G[gi].sid:-1;
    return;
  }
  errx("bad expression (expected a number, string, list, name)");
}

/* ---- builtins ---- */
static void emit_call_builtin(const char**p,const char*n,int depth){
  (void)depth;
  if(**p!='(') errx("expected ( after %s",n,NULL);
  (*p)++;
  if(!strcmp(n,"concat")){
    /* args are converted to string pointers and staged on the machine
       stack: the second arg may call a builtin (chr/concat) whose malloc
       maps a fresh chunk and clobbers rdi/rsi */
    emit_expr(p,0);
    if(XK==K_STR) push_r(AX);
    else if(XK==K_NUM){ callb(B_N2STR); push_r(AX); }
    else errx("concat needs strings or numbers");
    sw(p);
    if(**p!=',') errx("concat takes 2 args");
    (*p)++;
    emit_expr(p,0);
    if(XK==K_STR) push_r(AX);
    else if(XK==K_NUM){ callb(B_N2STR); push_r(AX); }
    else errx("concat needs strings or numbers");
    sw(p);
    if(**p!=')') errx("concat takes 2 args");
    (*p)++;
    pop_r(SI); pop_r(DI);
    callb(B_CONCAT);
    XK=K_STR; XS=-1;
    return;
  }
  if(!strcmp(n,"len")){
    emit_expr(p,0);
    if(XK==K_LIST) callb(B_LLEN);
    else if(XK==K_STR) callb(B_STRLEN);
    else errx("len takes a string or a list");
    emit_i2d();
    sw(p); if(**p!=')') errx("len takes 1 arg"); (*p)++;
    XK=K_NUM; XS=-1;
    return;
  }
  if(!strcmp(n,"chr")){
    emit_expr(p,0);
    if(XK!=K_NUM) errx("chr takes a number");
    emit_d2i();
    callb(B_CHR);
    sw(p); if(**p!=')') errx("chr takes 1 arg"); (*p)++;
    XK=K_STR; XS=-1;
    return;
  }
  if(!strcmp(n,"sx_index")||!strcmp(n,"index")){
    emit_expr(p,0);
    if(XK!=K_STR) errx("%s takes a string",n,NULL);
    push_r(AX);                    /* stage the string: the index may be a call */
    sw(p); if(**p!=',') errx("%s takes 2 args",n,NULL); (*p)++;
    emit_expr(p,0);
    if(XK!=K_NUM) errx("%s: the index must be a number",n,NULL);
    emit_d2i();
    mv_rr(SI,AX);
    sw(p); if(**p!=')') errx("%s takes 2 args",n,NULL); (*p)++;
    pop_r(DI);
    callb(B_SGET);
    emit_i2d();
    XK=K_NUM; XS=-1;
    return;
  }
  if(!strcmp(n,"read_file")){
    emit_expr(p,0);
    if(XK!=K_STR) errx("read_file takes a string (the path)");
    mv_rr(DI,AX);                  /* B_READFILE takes the path in rdi */
    callb(B_READFILE);
    sw(p); if(**p!=')') errx("read_file takes 1 arg"); (*p)++;
    XK=K_STR; XS=-1;
    return;
  }
  if(!strcmp(n,"write_file")){
    emit_expr(p,0);
    if(XK!=K_STR) errx("write_file takes (path, text)");
    push_r(AX);                    /* stage the path: the text may be a call */
    sw(p); if(**p!=',') errx("write_file takes 2 args",n,NULL); (*p)++;
    emit_expr(p,0);
    if(XK!=K_STR) errx("write_file takes (path, text)");
    mv_rr(SI,AX);
    sw(p); if(**p!=')') errx("write_file takes 2 args",n,NULL); (*p)++;
    pop_r(DI);
    callb(B_WRITEFILE);
    emit_i2d();
    XK=K_NUM; XS=-1;
    return;
  }
  if(!strcmp(n,"arg")){
    emit_expr(p,0);
    if(XK!=K_NUM) errx("arg takes a number");
    emit_d2i();
    callb(B_ARG);
    sw(p); if(**p!=')') errx("arg takes 1 arg"); (*p)++;
    XK=K_STR; XS=-1;
    return;
  }
  if(!strcmp(n,"arg_count")){
    sw(p);
    if(**p!=')') errx("arg_count takes no args");
    (*p)++;
    callb(B_ARGC);
    emit_i2d();
    XK=K_NUM; XS=-1;
    return;
  }
  if(!strcmp(n,"string_eq")||!strcmp(n,"sx_eq")){
    emit_expr(p,0);
    if(XK!=K_STR) errx("%s takes 2 strings",n,NULL);
    push_r(AX);                    /* stage a: b may be a call */
    sw(p); if(**p!=',') errx("%s takes 2 args",n,NULL); (*p)++;
    emit_expr(p,0);
    if(XK!=K_STR) errx("%s takes 2 strings",n,NULL);
    mv_rr(SI,AX);
    sw(p); if(**p!=')') errx("%s takes 2 args",n,NULL); (*p)++;
    pop_r(DI);
    callb(B_CMPSTR);
    emit_i2d();
    XK=K_NUM; XS=-1;
    return;
  }
  if(!strcmp(n,"push")){
    /* if the list argument is a plain global, remember it: push may grow the
       list, in which case the new list pointer must be stored back into it */
    const char*q=*p; char w[64]; int wi=0;
    while(idc(*q)&&wi+1<64) w[wi++]=*q++; w[wi]=0;
    int gi=(wi>0)?g_find(w):-1;
    const char*q2=q; sw(&q2);
    if(gi>=0&&*q2!=',') gi=-1;
    emit_expr(p,0);
    if(XK!=K_LIST) errx("push takes (list, number)");
    push_r(AX);                    /* stage the list: the value may be a call */
    sw(p); if(**p!=',') errx("push takes 2 args"); (*p)++;
    emit_expr(p,0);
    if(XK!=K_NUM) errx("push takes (list, number)");
    mv_rr(SI,AX);
    sw(p); if(**p!=')') errx("push takes 2 args"); (*p)++;
    pop_r(DI);
    callb(B_LPUSH);
    if(gi>=0) store_global(gi);
    XK=K_LIST; XS=-1;
    return;
  }
  errx("unknown builtin %s",n,NULL);
}

/* Software signed division (this host's idiv mishandles negative dividends).
   In:  rax = a (dividend), rcx = b (divisor, already known != 0)
   Out: rax = a/b (trunc toward zero), rdx = a%b
   Clobbers: r8, r9, r10, r11. */
static void emit_sdiv(void){
  mv_rr(8,AX);         /* r8 = a */
  mv_rr(9,CX);         /* r9 = b */
  mv_rr(10,AX);
  sar_imm(10,63);      /* sar r10,63  -> mask_a */
  xor_rr(8,10);        /* r8 = a ^ mask_a */
  bin_rr(0x29,8,10);   /* sub r8,mask_a -> |a| */
  mv_rr(11,CX);
  sar_imm(11,63);      /* sar r11,63  -> mask_b */
  xor_rr(9,11);        /* r9 = b ^ mask_b */
  bin_rr(0x29,9,11);   /* sub r9,mask_b -> |b| */
  xor_rr(10,11);       /* r10 = mask_a ^ mask_b = sign */
  mv_rr(AX,8);         /* rax = |a| (div uses rdx:rax) */
  xor_rr(DX,DX);       /* rdx = 0 */
  fm7(6,9);            /* div r9 (gas: F7 /6 = DIV) -> rax=|a|/|b|, rdx=|a|%|b| */
  xor_rr(AX,10);
  bin_rr(0x29,AX,10);  /* rax = signed quotient */
  xor_rr(DX,10);
  bin_rr(0x29,DX,10);  /* rdx = signed remainder */
}

/* ---- term / rel / expr ---- */
/* primary + postfix chains; see pk_post for why this is its own step */
static void emit_post(const char**p,int depth){
  emit_prim(p,depth);
  for(;;){
    const char*q=*p; sw(&q);
    /* postfix */
    if(*q=='['){
      if(XK!=K_LIST&&XK!=K_STR) errx("cannot index a %s",kname(XK));
      int base_kind=XK;
      (*p)=q; (*p)++;
      /* The base pointer rides on the machine stack, not in a global data
         slot: stack discipline survives a function call INSIDE the index
         expression (recursion used to clobber the shared slot) and removes
         the old 4-deep nesting limit. */
      push_r(AX);                  /* [stack] = base */
      emit_expr(p,depth+1);
      if(XK!=K_NUM) errx("index must be a number");
      emit_d2i();
      mv_rr(SI,AX);                /* rsi = (long)index */
      pop_r(AX);                   /* rax = base */
      mv_rr(DI,AX);                /* rdi = base: B_LGET and B_SGET both read
                                      the base from rdi (the old string path
                                      never set it and read a stale pointer,
                                      which died as "string index out of
                                      range" on every s[i]) */
      if(base_kind==K_LIST) callb(B_LGET); else { callb(B_SGET); emit_i2d(); }
      sw(p);
      if(**p!=']') errx("expected ] after index");
      (*p)++;
      XK=K_NUM; XS=-1;
      continue;
    }
    if(*q=='.'){
      if(XK!=K_STRUCT) errx("cannot access a field (value is %s)",kname(XK));
      int sid=XS;
      if(sid<0) errx("cannot resolve the struct type here");
      (*p)=q; (*p)++;
      char fn[64];
      if(!pid(p,fn,64)) errx("expected a field name after .");
      int fi=s_field(sid,fn);
      if(fi<0) errx("no field '%s' in struct '%s'",fn,S[sid].name);
      mv_r64m(AX,AX,-1,0,8*fi);      /* field value = *(base+8*fi) */
      XK=S[sid].f[fi].kind;
      XS=(XK==K_STRUCT)?S[sid].f[fi].sid:-1;
      continue;
    }
    break;
  }
  return;
}
static void emit_term(const char**p,int depth){
  emit_post(p,depth);
  for(;;){
    sw(p); char op=**p;
    if(op!='*'&&op!='/'&&op!='%') break;
    if(op=='/'&&(*p)[1]=='/') break;   /* a // comment on the next line, not a division */
    if(XK!=K_NUM) errx("%c is numeric-only",op);
    (*p)++;
    /* the left operand MUST live on the machine stack, not in r15: the
       right side is a full postfix primary and a nested `*`/`/`/`%` used
       to clobber r15, so `a + 3 * 4` evaluated as (a+3)*4.  push/pop
       survives every callee (builtins use r9/r11/r13/r14 and calls are
       balanced). */
    push_r(AX);                  /* [stack] = left */
    emit_post(p,depth);
    if(XK!=K_NUM) errx("%c is numeric-only",op);
    mv_rr(CX,AX);                /* rcx = right */
    pop_r(AX);                   /* rax = left */
    if(op=='*'){
      movq_xr(0,AX); movq_xr(1,CX); mulsd(0,1); movq_rx(AX,0);
    } else if(op=='/'){
      /* IEEE division, exactly what seed-min/gen2 compile to: 10 / 4 = 2.5,
         1 / 0 = inf, 0 / 0 = -nan (all printed like printf("%g")) */
      movq_xr(0,AX); movq_xr(1,CX); divsd(0,1); movq_rx(AX,0);
    } else {
      /* numbers are doubles: `/` is a true division (10 / 4 = 2.5, as in
         seed-min/gen2); `%` truncates both sides to integers first, exactly
         like the C `(long)a % (long)b` seed-min and gen2 emit. */
      /* `%` truncates both sides to integers first, like the C
         `(long)a % (long)b` seed-min and gen2 emit; a zero divisor exits
         with "division by zero" (the C programs die of SIGFPE there) */
      size_t jz;
      movq_xr(1,CX); cvttsd2si(CX,1);    /* rcx = (long)right */
      test_rr(CX,CX);                    /* modulo by zero? */
      jz=cn; jcc_rel32(JC_Z,0);
      emit_d2i();                        /* rax = (long)left */
      emit_sdiv();                       /* rdx = left % right */
      mv_rr(AX,DX); emit_i2d();
      size_t jmp_at=cn;
      jmp_rel32(0);             /* skip die code (patched below) */
      size_t die_code=cn;
      lea_rm(AX,12,-1,0,(int)d_err_div);
      callb(B_DIE);
      { int32_t dd=(int32_t)(cn-(jmp_at+5)); memcpy(code+jmp_at+1,&dd,4); }
      erel32(jz,die_code);
    }
  }
  return;
}

static void emit_rel(const char**p,int depth){
  emit_term(p,depth);
  for(;;){
    sw(p); char op=**p;
    if(op!='+'&&op!='-') break;
    (*p)++;
    push_r(AX);                  /* [stack] = left (value or ptr) */
    int lk=XK;
    emit_term(p,depth);
    pop_r(CX);                   /* rcx = left */
    if(op=='+'){
      if(lk==K_STR||XK==K_STR){
        /* both operands are staged on the machine stack: B_N2STR calls
           malloc, which clobbers rdi -- `"a" + 1` used to concat the
           number's buffer with itself and print "11" */
        if(lk!=K_STR&&lk!=K_NUM) errx("+ is for numbers or strings");
        if(XK!=K_STR&&XK!=K_NUM) errx("+ is for numbers or strings");
        push_r(AX);                    /* [right] */
        mv_rr(AX,CX);
        if(lk!=K_STR) callb(B_N2STR);  /* rax = left as a string */
        pop_r(CX);                     /* rcx = right */
        push_r(AX);                    /* [left string] */
        mv_rr(AX,CX);
        if(XK!=K_STR) callb(B_N2STR);  /* rax = right as a string */
        mv_rr(SI,AX);
        pop_r(DI);
        callb(B_CONCAT);
        XK=K_STR; XS=-1;
      } else {
        if(lk!=K_NUM||XK!=K_NUM) errx("+ is for numbers or strings");
        movq_xr(0,CX); movq_xr(1,AX); addsd(0,1); movq_rx(AX,0);   /* left + right */
      }
    } else {
      if(lk!=K_NUM||XK!=K_NUM) errx("- is numeric-only");
      movq_xr(0,CX); movq_xr(1,AX); subsd(0,1); movq_rx(AX,0);   /* left - right */
    }
  }
}

static void emit_expr(const char**p,int depth){
  emit_rel(p,depth);
  sw(p);
  char c0=**p,c1=(*p)[1];
  int is2=0; const char*op=NULL;
  if(c0=='='&&c1=='='){ is2=1; op="=="; }
  else if(c0=='!'&&c1=='='){ is2=1; op="!="; }
  else if(c0=='<'&&c1=='='){ is2=1; op="<="; }
  else if(c0=='>'&&c1=='='){ is2=1; op=">="; }
  else if(c0=='<'){ is2=0; op="<"; }
  else if(c0=='>'){ is2=0; op=">"; }
  if(!op) return;
  if(XK==K_LIST||XK==K_STRUCT) errx("cannot compare %s with a value",kname(XK));
  *p += is2? 2 : 1;
  push_r(AX);                    /* [stack] = left */
  int lk=XK;
  emit_rel(p,depth);
  pop_r(CX);                     /* rcx = left */
  if(lk==K_STR){
    if(XK!=K_STR) errx("string compared with a non-string");
    mv_rr(DI,CX);
    mv_rr(SI,AX);
    callb(B_CMPSTR);
    if(op[0]=='='){                   /* == : equal -> 1 */
      test_rr(AX,AX); setcc(JC_NZ,AX); movzx_al_to_rax();
    } else {                          /* != : different -> 1 */
      test_rr(AX,AX); setcc(JC_Z,AX); movzx_al_to_rax();
    }
    emit_i2d();
  } else {
    if(XK!=K_NUM) errx("number compared with %s",kname(XK));
    /* ucomisd left, right sets CF/ZF like an UNSIGNED compare */
    movq_xr(0,CX); movq_xr(1,AX); ucomisd(0,1);
    int cc;
    if(!strcmp(op,"==")) cc=JC_Z;
    else if(!strcmp(op,"!=")) cc=JC_NZ;
    else if(!strcmp(op,"<")) cc=JC_B;            /* setb  */
    else if(!strcmp(op,"<=")) cc=6;              /* setbe */
    else if(!strcmp(op,">")) cc=7;               /* seta  */
    else cc=JC_NBE;                              /* setae */
    setcc(cc,AX);
    movzx_al_to_rax();
    emit_i2d();                                  /* 0.0 / 1.0 */
  }
  XK=K_NUM; XS=-1;
}

/* ---- statements ---- */
static void emit_fn(int fi,const char**p){
  if(fi<0) errx("unknown function");
  F[fi].start=(int)cn;
  push_r(BP);
  mv_rr(BP,SP);
  /* The frame must keep EVERY spill slot above rsp: expression codegen
     pushes temporaries and calls push return addresses below rsp, so a
     fixed 32-byte frame let a 5th/6th parameter (rbp-40/rbp-48) be
     overwritten by the first push or call in the body.  16-aligned so the
     (push rbp; sub rsp,frame) entry keeps the same alignment everywhere. */
  int frame=(8*F[fi].nparam+16+15)&~15;
  bin_imm8(5,SP,(uint8_t)frame);                /* sub rsp, frame */
  lea_r12_data();
  /* spill the incoming parameter registers into the frame.  Emitted with
     the same encoder helpers as everything else -- the old hand-written
     byte table spilled rbx/r13/r9 for parameters 1/3/4 (rdi/rdx/rcx), so
     every call read garbage for those arguments. */
  for(int i=0;i<F[fi].nparam;i++) mv_m64(BP,-1,0,-8*(i+1),argreg[i]);
  /* skip the source: (params) { */
  sw(p);
  if(**p!='(') errx("make %s: expected (params)",F[fi].name,NULL);
  (*p)++;
  for(;;){
    sw(p);
    if(**p==')'){ (*p)++; break; }
    char pm[64];
    if(!pid(p,pm,64)) errx("make %s: bad param list",F[fi].name,NULL);
    sw(p);
    if(**p==','){ (*p)++; continue; }
    if(**p==')'){ (*p)++; break; }
    errx("make %s: bad param list",F[fi].name,NULL);
  }
  sw(p);
  if(**p!='{') errx("make %s: expected { ... }",F[fi].name,NULL);
  (*p)++;
  cur_fn=fi;
  emit_prog(p,1,1);                   /* consumes the closing } */
  cur_fn=-1;
  mov_imm64(AX,0);                   /* fall-off returns 0 */
  e1(0xc9); e1(0xc3);                /* leave; ret */
}

static void emit_prog(const char**p,int in_fn,int stop){
  for(;;){
    sw(p);
    if(!**p) return;
    if(stop&&**p=='}'){ (*p)++; return; }
    if(**p=='/'&&(*p)[1]=='/'){ while(**p&&**p!='\n') (*p)++; continue; }
    const char*line=*p; sw(p);
    if(mkw(p,"hold")){
      char nm[64];
      if(!pid(p,nm,64)) errx("hold needs a name");
      if(cur_fn>=0)
        errx("hold inside make is not in the native subset (a local would live in the shared data segment and be clobbered by recursion); compute in give expressions, or assign to a global held at the top level");
      sw(p);
      if(**p!='=') errx("hold needs '='");
      (*p)++;
      int gi=g_decl(nm);
      emit_expr(p,0);
      int k=XK;
      if(k==K_UNK) errx("cannot infer the type of variable '%s'",nm,NULL);
      if(G[gi].kind==K_UNK){ G[gi].kind=k; G[gi].sid=(k==K_STRUCT)?XS:-1; }
      else if(G[gi].kind!=k) errx("variable '%s' is used with two different types",nm,NULL);
      else if(G[gi].kind==K_STRUCT&&G[gi].sid<0&&XS>=0){ G[gi].sid=XS; }
      if(k==K_STRUCT){
        if(XS<0) errx("cannot infer the struct type of '%s'",nm,NULL);
      }
      /* struct literals already live in their own heap block; store the
       * pointer directly (no copy). */
      store_global(gi);
      endstmt(p);
      continue;
    }
    if(mkw(p,"show")){
      sw(p);
      emit_expr(p,0);
      if(XK==K_NUM) callb(B_SHOWNUM);
      else if(XK==K_STR) callb(B_PUTSTR);
      else if(XK==K_LIST) callb(B_SHOWLIST);
      else errx("show of a struct value is not supported");
      endstmt(p);
      continue;
    }
    if(mkw(p,"when")){
      emit_expr(p,0);
      if(XK==K_UNK) errx("cannot infer the type of the condition");
      if(XK!=K_NUM) errx("when condition must be a number (got %s)",kname(XK));
      bin_rr(1,AX,AX);             /* add rax,rax: ZF iff the double is +-0.0 */
      size_t jz_at=cn; jcc_rel32(JC_Z,0);
      sw(p);
      if(**p!='{') errx("when needs { ... }");
      (*p)++;
      emit_prog(p,in_fn,1);
      sw(p);
      if(mkw(p,"otherwise")||mkw(p,"else")){
        /* false -> the else block below; the then body must skip over it with
           an unconditional jump (its instructions destroy the cond flags).
           jz_at must target the FIRST BYTE of the else body, i.e. the offset
           right after that unconditional jump.  It must not target a second
           conditional jump placed there: control would arrive with the
           condition's flags still live, so the false case would take that JZ
           and jump straight past the else body -- silently printing nothing
           for `when c { .. } else { .. }` when c was false. */
        size_t jmpend_at=cn; jmp_rel32(0);
        size_t j2=cn;                      /* else-body entry (no instruction) */
        sw(p);
        if(**p!='{') errx("else needs { ... }");
        (*p)++;
        emit_prog(p,in_fn,1);
        erel32j(jmpend_at,cn);
        erel32(jz_at,j2);
      } else erel32(jz_at,cn);
      continue;
    }
    if(mkw(p,"while")){
      size_t top=cn;
      emit_expr(p,0);
      if(XK==K_UNK) errx("cannot infer the type of the condition");
      if(XK!=K_NUM) errx("while condition must be a number (got %s)",kname(XK));
      bin_rr(1,AX,AX);             /* add rax,rax: ZF iff the double is +-0.0 */
      size_t jz_at=cn; jcc_rel32(JC_Z,0);
      sw(p);
      if(**p!='{') errx("while needs { ... }");
      (*p)++;
      emit_prog(p,in_fn,1);
      jmp_rel32((int32_t)(top-cn-5));
      erel32(jz_at,cn);
      continue;
    }
    if(mkw(p,"make")){
      /* The definition is only SKIPPED here (it must never run inline);
         every top-level body is emitted after main's exit syscall by the
         emit_all_fns walk in main(), and call sites are patched against
         F[].start, so definition order and recursion are fine.  A make
         inside a block or another function is not valid in the shared
         dialect (seed-min rejects it too). */
      if(in_fn||stop) errx("make must be at the top level (not inside a block or another function)");
      *p=skip_stmt(line);
      continue;
    }
    if(mkw(p,"give")){
      if(!in_fn) errx("give outside a make function");
      emit_expr(p,0);
      if(XK==K_UNK) errx("cannot infer the type of the give value");
      if(XK!=K_NUM) errx("give must give a number (got %s)",kname(XK));
      e1(0xc9); e1(0xc3);             /* leave; ret */
      endstmt(p);
      continue;
    }
    if(mkw(p,"struct")){
      *p=skip_stmt(line);
      continue;
    }
    {
      char w[64]; const char*q=*p; int i=0;
      while(idc(*q)&&i+1<64) w[i++]=*q++; w[i]=0;
      /* gen2-only full-language statements: name them, do not let them fall
         through to the assignment/undefined-variable path (`for c in s` used
         to die as "undefined variable 'c'") */
      if(i>0&&(!strcmp(w,"for")||!strcmp(w,"break")||!strcmp(w,"continue")||!strcmp(w,"elif")))
        errx("'%s' is a full-language statement and not in the native subset (native speaks the pure-min statements; use selfhost/gen2)",w,NULL);
      const char*q2=q; sw(&q2);
      if(i>0&&*q2=='='){
        /* plain assignment statement:  a = expr  (global or parameter) */
        int gi=g_find(w);
        int pi=-1;
        if(gi<0&&cur_fn>=0){
          for(int j=0;j<F[cur_fn].nparam;j++)
            if(!strcmp(F[cur_fn].params[j],w)){ pi=j; break; }
        }
        if(gi<0&&pi<0) errx("cannot assign to \"%s\" (hold it first)",w,NULL);
        (*p)=q2; (*p)++;
        emit_expr(p,0);
        if(XK==K_UNK) errx("cannot infer the type of the assignment value");
        if(pi>=0){
          if(XK!=K_NUM) errx("assignment to parameter '%s' must be a number",w,NULL);
          mv_m64(BP,-1,0,-8*(pi+1),AX);
        } else {
          if(XK==K_STRUCT) errx("assignment of a struct value to '%s' is not supported (use hold for a fresh copy)",w,NULL);
          if(G[gi].kind==K_UNK){ G[gi].kind=XK; G[gi].sid=-1; }
          else if(G[gi].kind!=XK) errx("variable '%s' is used with two different types",w,NULL);
          store_global(gi);
        }
        endstmt(p);
        continue;
      }
      if(i>0&&*q2=='('&&!strcmp(w,"push")){
        /* bare call statement.  Only push(xs, v) is part of the statement set
           seed-min and gen2 share; a bare `write_file(...)` (or any other
           call) is `unknown statement` there, so native rejects it too
           instead of quietly accepting a wider subset. */
        emit_expr(p,0);
        endstmt(p);
        continue;
      }
      errx("unknown statement: \"%s\" (native speaks hold/show/when/else/while/make/give/struct, or the bare call push(xs, v))",w,NULL);
    }
  }
}

/* ================= phase 4: runtime builtins ================= */
/* while rdx>0: [r10+rcx] = byte [rsi]; rcx++ */
static void emit_cpybyte_r10(void){
  /* [r10+rcx] = [rsi+r10src], rcx++, r10src++ (r10 = source index, rcx = dest index) */
  size_t L=cn;
  test_rr(DX,DX);
  size_t jz=cn; jcc_rel32(JC_Z,0);
  mvz_rm(AX,SI,10,0,-1);
  rexb(0, 0, CX>7, 8>7); e1(0x88); emit_modrm(AX&7, 8, 0, CX, -1);
  incdec_r(1,CX);
  incdec_r(1,10);
  bin_imm8(5,DX,1);
  jmp_rel32((int32_t)(L-cn-5));
  erel32(jz,cn);
}
/* while rdx>0: [sp+rcx] = byte [rdi]; rcx++ */
static void emit_cpybyte_stack(void){
  size_t L=cn;
  test_rr(DX,DX);
  size_t jz=cn; jcc_rel32(JC_Z,0);
  mvz_rm(AX,DI,CX,0,-1);
  rexb(0, 0, CX>7, SP>7); e1(0x88); emit_modrm(AX&7, SP, 0, CX, -1);
  incdec_r(1,CX);
  bin_imm8(5,DX,1);
  jmp_rel32((int32_t)(L-cn-5));
  erel32(jz,cn);
}
/* digits of rcx into a downward buffer at rsi (top marker already 0);
 * on return rsi = first byte */
static void emit_digs(int topdisp){
  (void)topdisp;
  test_rr(CX,CX);
  size_t jns=cn; jcc_rel32(JC_JNS,0);
  mov_imm64(8,1);
  fm7(3,CX);
  erel32(jns,cn);
  test_rr(CX,CX);
  size_t jnz=cn; jcc_rel32(JC_NZ,0);
  bin_imm8(5,SI,1);
  e1(0xc6); e1(0x06); e1('0');        /* mov byte [rsi], '0' */
  size_t jmpsign=cn; e1(0xe9); e32(0);/* jmp sign block (forward, patched) */
  size_t dig=cn;
  xor_rr(DX,DX);
  mv_rr(AX,CX);
  mov_imm64(9,10);
  fm7(6,9);                           /* div r9 (10) */
  mv_rr(CX,AX);
  bin_imm8(0,DX,0x30);
  bin_imm8(5,SI,1);
  e1(0x88); e1(0x16);                 /* mov [rsi], dl (verified vs gas) */
  test_rr(CX,CX);
  size_t jnz2=cn; jcc_rel32(JC_NZ,0); erel32(jnz2,dig);
  size_t sign=cn;
  erel32(jnz,dig);
  { int32_t jd=(int32_t)(sign-(jmpsign+5)); memcpy(code+jmpsign+1,&jd,4); }
  test_rr(8,8);
  size_t jz=cn; jcc_rel32(JC_Z,0);
  bin_imm8(5,SI,1);
  e1(0xc6); e1(0x06); e1('-');
  erel32(jz,cn);
}

static void emit_builtins(void){
  /* r_malloc: rdi=size -> rax=ptr */
  {
  builtin_off[B_MALLOC]=cn;
  /* r_malloc: rdi=size -> rax=ptr. Bump allocator over lazy 64KiB mmap chunks.
     Preserves r8-r11 (callee-saves) so callers may keep values there. */
  push_r(12);
  push_r(11);
  push_r(10);
  push_r(9);
  push_r(8);
  push_r(3);                       /* rbx: the slow path uses it */
  mv_r64m(AX,12,-1,0,OFF_CUR);    /* rax = cursor */
  mv_rr(11,DI);                    /* r11 = size */
  bin_imm8(0,11,7);                /* r11 += 7 */
  shr_imm(11,3);                   /* r11 >>= 3 */
  shl_imm(11,3);                   /* r11 = size rounded up to 8 */
  lea_rm(8,AX,11,0,0);             /* r8 = cursor + size8 (needed end) */
  mv_r64m(9,12,-1,0,OFF_END);      /* r9 = end of current chunk */
  bin_rr(0x39,9,8);                /* cmp end, need: flags = end - need */
  size_t fast=cn;
  jcc_rel32(JC_GE,0);              /* jge .ok (end >= need) */
  /* slow path: mmap a fresh 64KiB chunk */
  mv_rr(3,11);                     /* rbx = size8 (syscalls clobber rcx/r11; rbx is free) */
  mov_imm64(AX,9);                 /* syscall: mmap */
  xor_rr(DI,DI);                   /* addr = NULL */
  /* len = max(64KiB, request) rounded up to a page: a request bigger than
     64KiB (read_file of a large file, a long concat) used to get a 64KiB
     chunk and run off its end */
  lea_rm(SI,11,-1,0,65536+4095);
  bin_imm32(4,SI,0xFFFFF000u);     /* and rsi, ~4095 */
  mov_imm64(DX,3);                 /* prot = RW */
  mov_imm64(10,0x22);              /* flags = private|anon */
  mov_imm64(8,-1);                 /* fd = -1 */
  xor_rr(9,9);                     /* off = 0 */
  e1(0x0f); e1(0x05);              /* syscall */
  test_rr(AX,AX);
  size_t js=cn; jcc_rel32(JC_JS,0); /* js .die (negative errno) */
  mv_rr(11,3);                     /* r11 = size8 (restored; syscall clobbered it) */
  mv_rr(9,AX);                     /* r9 = chunk start */
  lea_rm(AX,AX,SI,0,0);            /* rax = chunk start + len (syscall keeps rsi) */
  mv_m64(12,-1,0,OFF_END,AX);      /* end = chunk start + len */
  mv_rr(AX,9);                     /* cursor = chunk start */
  erel32(fast,cn);
  lea_rm(8,AX,11,0,0);             /* r8 = cursor + size8 */
  mv_m64(12,-1,0,OFF_CUR,8);       /* cursor += size8 */
  pop_r(3); pop_r(8); pop_r(9); pop_r(10); pop_r(11); pop_r(12); e1(0xc3);
  erel32(js,cn);
  lea_rm(AX,12,-1,0,(int)d_err_malloc);
  callb(B_DIE);
  }
  /* r_strlen: rax=ptr -> rax=n */
  {
  builtin_off[B_STRLEN]=cn;
  push_r(12);
  mv_rr(SI,AX);
  xor_rr(CX,CX);
  {
    size_t L=cn;
    e1(0x80); e1(0x3c); e1(0x0e); e1(0x00);   /* cmp byte [rsi+rcx], 0 (verified vs gas) */
    size_t jz=cn; jcc_rel32(JC_Z,0);
    incdec_r(1,CX);
    jmp_rel32((int32_t)(L-cn-5));
    size_t exit_at=cn;
    mv_rr(AX,CX);
    pop_r(12); e1(0xc3);
    erel32(jz,exit_at);
  }
  }

  /* r_strcmp: rdi=a rsi=b -> rax 1 if equal */
  {
  builtin_off[B_CMPSTR]=cn;
  push_r(12);
  {
    size_t L=cn;
    mvz_rm(AX,DI,-1,0,0);
    mvz_rm(11,SI,-1,0,0);
    bin_rr(0x39,AX,11);
    size_t jne=cn; jcc_rel32(JC_NZ,0);
    test_rr(AX,AX);
    size_t jz=cn; jcc_rel32(JC_Z,0);
    incdec_r(1,DI);
    incdec_r(1,SI);
    jmp_rel32((int32_t)(L-cn-5));
    size_t eq=cn;
    mov_imm64(AX,1);
    size_t jmp_at=cn;
    jmp_rel32(0);
    size_t zc=cn;
    xor_rr(AX,AX);
    size_t ret_at=cn;
    { int32_t dd=(int32_t)(ret_at-(jmp_at+5)); memcpy(code+jmp_at+1,&dd,4); }
    pop_r(12); e1(0xc3);
    erel32(jne,zc); erel32(jz,eq);
  }
  }

  /* r_concat: rdi=a rsi=b -> rax=new */
  {
  builtin_off[B_CONCAT]=cn;
  push_r(12);
  mv_rr(9,SI);            /* r9 = b */
  mv_rr(14,DI);           /* r14 = a */
  mv_rr(AX,14);
  callb(B_STRLEN);
  mv_rr(11,AX);           /* r11 = len(a) */
  mv_rr(AX,9);
  callb(B_STRLEN);
  mv_rr(13,AX);           /* r13 = len(b) */
  mv_rr(AX,11);
  bin_rr(1,AX,13);        /* rax = len(a)+len(b) */
  bin_imm8(0,AX,2);
  mv_rr(DI,AX);
  callb(B_MALLOC);        /* preserves r8-r11 */
  mv_rr(8,AX);            /* r8 = new buffer */
  xor_rr(CX,CX);          /* dest index: continues across both copies */
  xor_rr(10,10);          /* src index: reset per copy */
  mv_rr(SI,14);           /* rsi = a */
  mv_rr(DX,11);
  emit_cpybyte_r10();
  xor_rr(10,10);
  mv_rr(SI,9);            /* rsi = b */
  mv_rr(DX,13);
  emit_cpybyte_r10();
  rexb(0, 0, CX>7, 8>7); e1(0xc6); emit_modrm(0, 8, 0, CX, -1); e1(0x00);
  mv_rr(AX,8);
  pop_r(12); e1(0xc3);
  }

  /* r_n2str: rax=double bits -> rax=fresh heap string, formatted like %g */
  {
  builtin_off[B_N2STR]=cn;
  push_r(12);
  push_r(AX);
  mov_imm64(DI,64);
  callb(B_MALLOC);
  mv_rr(DI,AX);                    /* rdi = buffer */
  pop_r(AX);                       /* rax = value */
  callb(B_NFMT);                   /* rax = buffer */
  pop_r(12); e1(0xc3);
  }

  /* r_shownum: rax=double bits -> write "%g\n" (static buffer, no heap) */
  {
  builtin_off[B_SHOWNUM]=cn;
  push_r(12);
  lea_rm(DI,12,-1,0,(int)d_numbuf);
  callb(B_NFMT);
  callb(B_PUTSTR);
  pop_r(12); e1(0xc3);
  }

  /* r_putstr: rax=ptr -> write s + '\n'.  Two direct write(2) calls: the
     old version copied the string into a 48-byte stack buffer, so any
     string longer than ~47 bytes overwrote the return address. */
  {
  builtin_off[B_PUTSTR]=cn;
  push_r(12);
  push_r(13);
  mv_rr(13,AX);
  callb(B_STRLEN);                 /* rax = len */
  mv_rr(DX,AX);
  mv_rr(SI,13);
  mov_imm64(DI,1);
  mov_imm64(AX,1);
  e1(0x0f); e1(0x05);              /* write(1, s, len) */
  lea_rm(SI,12,-1,0,(int)d_nl);
  mov_imm64(DX,1);
  mov_imm64(DI,1);
  mov_imm64(AX,1);
  e1(0x0f); e1(0x05);              /* write(1, "\n", 1) */
  pop_r(13);
  pop_r(12); e1(0xc3);
  }

  /* r_wcstr: rax=ptr -> write s (no newline); same direct write */
  {
  builtin_off[B_WCSTR]=cn;
  push_r(12);
  push_r(13);
  mv_rr(13,AX);
  callb(B_STRLEN);
  mv_rr(DX,AX);
  mv_rr(SI,13);
  mov_imm64(DI,1);
  mov_imm64(AX,1);
  e1(0x0f); e1(0x05);
  pop_r(13);
  pop_r(12); e1(0xc3);
  }

  /* r_itono: rax=val -> write digits */
  {
  builtin_off[B_ITONO]=cn;
  push_r(12);
  mv_rr(CX,AX);
  bin_imm8(5,SP,48);
  lea_rm(SI,SP,-1,0,0x2f);
  rexb(0, 0, 0, 0); e1(0xc6); emit_modrm(0, SP, 0, -1, 0x2f); e1(0x00);
  mov_imm64(8,0);
  emit_digs(0x2f);
  lea_rm(DX,SP,-1,0,0x2f);
  bin_rr(0x29,DX,SI);
  mov_imm64(DI,1);
  mov_imm64(AX,1);
  e1(0x0f); e1(0x05);
  bin_imm8(0,SP,48);
  pop_r(12); e1(0xc3);
  }

  /* r_itowrite: rax=val -> digits + '\n' */
  {
  builtin_off[B_ITOWRITE]=cn;
  push_r(12);
  callb(B_ITONO);
  lea_rm(SI,12,-1,0,(int)d_nl);
  mov_imm64(DI,1);
  mov_imm64(DX,1);
  mov_imm64(AX,1);
  e1(0x0f); e1(0x05);
  pop_r(12); e1(0xc3);
  }

  /* r_showlist: rax=list -> "[list len=N" + n + "]" */
  {
  builtin_off[B_SHOWLIST]=cn;
  push_r(12);
  mv_rr(13,AX);                    /* r13 = list (write syscalls clobber rcx/r11) */
  lea_rm(AX,12,-1,0,(int)d_list1);
  callb(B_WCSTR);
  mv_r64m(AX,13,-1,0,0);
  callb(B_ITONO);
  lea_rm(AX,12,-1,0,(int)d_list2);
  callb(B_WCSTR);
  pop_r(12); e1(0xc3);
  }

  /* r_mlist: rax=n -> list ptr */
  {
  builtin_off[B_MLIST]=cn;
  push_r(12);
  mv_rr(11,AX);                       /* r11 = n */
  mv_rr(DX,11);
  bin_imm8(7,DX,4);                   /* cmp n, 4 */
  size_t jb=cn; jcc_rel32(JC_B,0);
  size_t jmp_at=cn;
  jmp_rel32(0);
  size_t set4=cn;
  mov_imm64(DX,4);
  size_t skip=cn;
  { int32_t dd=(int32_t)(skip-(jmp_at+5)); memcpy(code+jmp_at+1,&dd,4); }
  erel32(jb,set4);
  lea_rm(DX,DX,-1,0,3);               /* dx = n+3 */
  bin_imm8(4,DX,0xFC);                /* slots = (n+3)&~3, >= 4 */
  shl_imm(DX,3);                      /* 8*slots */
  bin_imm8(0,DX,24);                  /* 24 + 8*slots */
  mv_rr(DI,DX);
  callb(B_MALLOC);
  mv_rr(10,AX);                       /* r10 = list */
  mv_m64(10,-1,0,0,11);               /* list->n = n */
  mv_rr(DX,11);
  bin_imm8(7,DX,4);
  size_t jb2=cn; jcc_rel32(JC_B,0);
  size_t jmp_at2=cn;
  jmp_rel32(0);
  size_t set4b=cn;
  mov_imm64(DX,4);
  size_t storecap=cn;
  { int32_t dd=(int32_t)(storecap-(jmp_at2+5)); memcpy(code+jmp_at2+1,&dd,4); }
  erel32(jb2,set4b);
  mv_m64(10,-1,0,16,DX);              /* list->cap = max(4,n) */
  mv_rr(AX,10);
  pop_r(12); e1(0xc3);
  }

  /* r_lget: rdi=list rsi=i -> rax */
  {
  builtin_off[B_LGET]=cn;
  push_r(12);
  mv_r64m(CX,DI,-1,0,0);
  mv_rr(11,SI);
  bin_rr(0x39,11,CX);
  size_t jge=cn; jcc_rel32(JC_GE,0);
  bin_imm8(7,11,0);
  size_t js=cn; jcc_rel32(JC_JS,0);
  mv_r64m(AX,DI,11,3,24);         /* rax = v[i] (elements are inline at +24) */
  pop_r(12); e1(0xc3);
  size_t die=cn;
  lea_rm(AX,12,-1,0,(int)d_err_list);
  callb(B_DIE);
  erel32(jge,die); erel32(js,die);
  }

  /* r_llen: rax=list -> n */
  {
  builtin_off[B_LLEN]=cn;
  push_r(12);
  mv_r64m(AX,AX,-1,0,0);
  pop_r(12); e1(0xc3);
  }

  /* r_lpush: rdi=list rsi=v -> list */
  {
  builtin_off[B_LPUSH]=cn;
  push_r(12);
  mv_rr(11,DI);                       /* r11 = list */
  mv_r64m(CX,11,-1,0,0);              /* cx = n */
  mv_r64m(DX,11,-1,0,16);             /* dx = cap */
  bin_rr(0x39,CX,DX);                 /* cmp n, cap */
  size_t jb=cn; jcc_rel32(JC_B,0);    /* n < cap -> fast */
  mv_rr(8,DX);                        /* r8 = cap */
  bin_rr(1,8,8);                      /* r8 = cap*2 */
  test_rr(8,8);
  size_t jz=cn; jcc_rel32(JC_Z,0);   /* overflow (==0) -> set 4 below */
  size_t jmp_skip=cn; jmp_rel32(0);  /* otherwise skip the set */
  mov_imm64(8,4);
  erel32j(jmp_skip,cn);
  mv_rr(DX,8);                        /* dx = newcap */
  shl_imm(DX,3);                      /* 8*newcap */
  bin_imm8(0,DX,24);
  mv_rr(10,CX);                       /* r10 = n (the malloc's mmap clobbers rcx; r10 is preserved) */
  mv_rr(13,SI);                       /* r13 = value (the malloc also clobbers rsi) */
  mv_rr(DI,DX);
  callb(B_MALLOC);
  mv_rr(9,AX);                        /* r9 = new */
  lea_rm(SI,11,-1,0,24);              /* rsi = old v */
  mv_rr(CX,10);                       /* rcx = n (restored) */
  {
    size_t L=cn;
    test_rr(CX,CX);
    size_t jz2=cn; jcc_rel32(JC_Z,0);
    incdec_r(0,CX);                   /* cx-- (FF /1 = DEC, matches gas) */
    mv_r64m(AX,SI,CX,3,0);            /* rax = oldv[cx] */
    mv_m64(9,CX,3,24,AX);             /* newv[cx] = rax */
    jmp_rel32((int32_t)(L-cn-5));
    erel32(jz2,cn);
  }
  mv_m64(9,10,3,24,13);               /* new->v[n] = value */
  mv_m64(9,-1,0,0,10);                /* new->n = n */
  inc_mem_r(9);                      /* inc [r9] (new->n = n+1) */
  mv_m64(9,-1,0,16,8);                /* new->cap = r8 */
  mv_rr(AX,9);                        /* rax = new list */
  size_t jmp_at=cn;
  jmp_rel32(0);                       /* slow path -> ret */
  size_t fast=cn;
  mv_m64(11,CX,3,24,SI);              /* v[n] = value (elements are inline at +24) */
  inc_mem_r(11);                     /* inc [r11] (list->n++) */
  mv_rr(AX,11);
  size_t ret_at=cn;
  { int32_t dd=(int32_t)(ret_at-(jmp_at+5)); memcpy(code+jmp_at+1,&dd,4); }
  pop_r(12); e1(0xc3);
  erel32(jb,fast);
  }

  /* r_sget: rdi=s rsi=i -> char code */
  {
  builtin_off[B_SGET]=cn;
  push_r(12);
  mv_rr(11,SI);                        /* r11 = i FIRST: B_STRLEN below uses
                                          rsi as its scan pointer and would
                                          otherwise eat the index (every
                                          s[i] died "string index out of
                                          range" with i = the end pointer) */
  mv_rr(AX,DI);
  callb(B_STRLEN);
  mv_rr(CX,AX);
  bin_imm8(7,11,0);                    /* SF = sign(i) */
  size_t jns=cn; jcc_rel32(JC_JNS,0);  /* i >= 0: skip adjust */
  bin_rr(1,11,CX);                     /* r11 = i + len */
  size_t js=cn; jcc_rel32(JC_JS,0);    /* still < 0 -> die */
  size_t ok=cn;
  erel32(jns,ok);
  bin_rr(0x39,11,CX);                  /* cmp i, len */
  size_t jge=cn; jcc_rel32(JC_GE,0);   /* i >= len -> die */
  mvz_rm(AX,DI,11,0,-1);               /* al = [s + i] */
  pop_r(12); e1(0xc3);
  size_t die=cn;
  lea_rm(AX,12,-1,0,(int)d_err_str);
  callb(B_DIE);
  erel32(js,die); erel32(jge,die);
  }

  /* r_chr: rax=v -> 1-char str */
  {
  builtin_off[B_CHR]=cn;
  push_r(12);
  mv_rr(11,AX);
  mov_imm64(DI,2);
  callb(B_MALLOC);
  mv_rr(10,11);
  bin_imm32(4,10,0xff);
  mv_m64(AX,-1,0,0,10);
  pop_r(12); e1(0xc3);
  }

  /* r_readfile: rdi=path -> whole file as a fresh string; "" if it cannot be
     opened or sized (same as seed-min/gen2's sx_read).  Size via lseek, one
     buffer of size+1, pread loop until size bytes or EOF. */
  {
  builtin_off[B_READFILE]=cn;
  int Lempty=L_new(), Lclose=L_new(), Lloop=L_new(), Ldone=L_new(), Lret=L_new();
  push_r(12); push_r(3); push_r(13); push_r(14); push_r(15);
  xor_rr(SI,SI);                        /* flags = O_RDONLY */
  xor_rr(DX,DX);
  mov_imm64(AX,2); e1(0x0f); e1(0x05);  /* open(path, 0) */
  test_rr(AX,AX); J_cc(JC_JS,Lempty);
  mv_rr(3,AX);                          /* rbx = fd */
  mv_rr(DI,3); xor_rr(SI,SI); mov_imm64(DX,2);
  mov_imm64(AX,8); e1(0x0f); e1(0x05);  /* lseek(fd, 0, SEEK_END) = size */
  test_rr(AX,AX); J_cc(JC_JS,Lclose);
  mv_rr(13,AX);                         /* r13 = size */
  lea_rm(DI,13,-1,0,1);
  callb(B_MALLOC);
  mv_rr(14,AX);                         /* r14 = buf */
  xor_rr(15,15);                        /* r15 = total */
  L_bind(Lloop);
  bin_rr(0x39,15,13);                   /* cmp total, size */
  J_cc(JC_GE,Ldone);
  mv_rr(DI,3);
  lea_rm(SI,14,15,0,0);                 /* buf + total */
  mv_rr(DX,13); bin_rr(0x29,DX,15);     /* size - total */
  mv_rr(10,15);                         /* offset = total */
  mov_imm64(AX,17); e1(0x0f); e1(0x05); /* pread64 */
  test_rr(AX,AX); J_cc(JC_LE,Ldone);
  bin_rr(1,15,AX);
  J_mp(Lloop);
  L_bind(Ldone);
  mov_imm8m(14,15,0,0,0);               /* buf[total] = 0 */
  mv_rr(DI,3); mov_imm64(AX,3); e1(0x0f); e1(0x05);  /* close */
  mv_rr(AX,14);
  J_mp(Lret);
  L_bind(Lclose);
  mv_rr(DI,3); mov_imm64(AX,3); e1(0x0f); e1(0x05);
  L_bind(Lempty);
  lea_rm(AX,12,-1,0,(int)d_empty);
  L_bind(Lret);
  pop_r(15); pop_r(14); pop_r(13); pop_r(3); pop_r(12); e1(0xc3);
  nlbl=0;
  }

  /* r_writefile: rdi=path rsi=s -> 1 written / 0 cannot open.  Like
     fopen(p,"wb"): O_WRONLY|O_CREAT|O_TRUNC (577), mode 0666 (438) in rdx
     (the old code put the mode in r10, omitted O_TRUNC and lost s, since
     syscalls clobber r11). */
  {
  builtin_off[B_WRITEFILE]=cn;
  int Lfail=L_new(), Lret=L_new(), Lw=L_new(), Lwdone=L_new();
  push_r(12); push_r(3); push_r(13); push_r(14);
  mv_rr(13,SI);                         /* r13 = s */
  mov_imm64(SI,577);
  mov_imm64(DX,438);
  mov_imm64(AX,2); e1(0x0f); e1(0x05);  /* open */
  test_rr(AX,AX); J_cc(JC_JS,Lfail);
  mv_rr(3,AX);                          /* rbx = fd */
  mv_rr(AX,13);
  callb(B_STRLEN);
  mv_rr(14,AX);                         /* r14 = bytes left */
  L_bind(Lw);
  test_rr(14,14); J_cc(JC_Z,Lwdone);
  mv_rr(DI,3); mv_rr(SI,13); mv_rr(DX,14);
  mov_imm64(AX,1); e1(0x0f); e1(0x05);  /* write */
  test_rr(AX,AX); J_cc(JC_LE,Lwdone);
  bin_rr(1,13,AX); bin_rr(0x29,14,AX);
  J_mp(Lw);
  L_bind(Lwdone);
  mv_rr(DI,3); mov_imm64(AX,3); e1(0x0f); e1(0x05);  /* close */
  mov_imm64(AX,1);
  J_mp(Lret);
  L_bind(Lfail);
  xor_rr(AX,AX);
  L_bind(Lret);
  pop_r(14); pop_r(13); pop_r(3); pop_r(12); e1(0xc3);
  nlbl=0;
  }

  /* r_arg: rax=i -> str */
  {
  builtin_off[B_ARG]=cn;
  push_r(12);
  mv_rr(11,AX);
  bin_imm8(7,11,0);
  size_t js=cn; jcc_rel32(JC_JS,0);
  mv_r64m(CX,12,-1,0,OFF_ARGC);
  bin_rr(0x39,11,CX);
  size_t jg=cn; jcc_rel32(JC_G,0);
  mv_r64m(10,12,-1,0,OFF_ARGV);
  mv_r64m(AX,10,11,3,0);
  test_rr(AX,AX);
  size_t jz=cn; jcc_rel32(JC_Z,0);
  size_t jmp_at=cn;
  jmp_rel32(0);                        /* valid -> ret */
  size_t empty=cn;
  lea_rm(AX,12,-1,0,(int)d_empty);
  { int32_t dd=(int32_t)(cn-(jmp_at+5)); memcpy(code+jmp_at+1,&dd,4); }
  erel32(js,empty); erel32(jg,empty); erel32(jz,empty);
  pop_r(12); e1(0xc3);
  }

  /* r_argc: -> argc */
  {
  builtin_off[B_ARGC]=cn;
  push_r(12);
  mv_r64m(AX,12,-1,0,OFF_ARGC);
  pop_r(12); e1(0xc3);
  }

  /* r_nfmt: rax=double bits, rdi=buffer (>= 32 bytes) -> rax=buffer holding
     the number formatted exactly like printf("%g") for the values a program
     meets in practice: 6 significant digits, trailing zeros dropped, fixed
     notation for exponents -4..5, else d.ddddde+XX; inf, -inf, nan, -nan;
     -0 prints as -0 (as printf does).
     Method: find the decimal exponent e with a table of exact powers of
     ten (1e0..1e308), scale to a 6-digit integer M = round(|x|*10^(5-e))
     (cvtsd2si, round-half-even), fix e if M spilled to 7 or 5 digits, then
     print the digits.  Preserves every register except rax. */
  {
  builtin_off[B_NFMT]=cn;
  int Lnan=L_new(), Lpos=L_new(), Linf=L_new(), Lzero=L_new(), Lsmall=L_new();
  int Lbig=L_new(), Lbigdone=L_new(), Lsl=L_new(), Lsdone=L_new(), Lhave=L_new();
  int Lcklow=L_new(), Ladj=L_new(), Ldg=L_new(), Lstrip=L_new(), Lsd=L_new();
  int Lexp=L_new(), Lfneg=L_new(), Lfi=L_new(), Lff=L_new(), Lfz=L_new(), Lfzd=L_new();
  int Lfd=L_new(), Led=L_new(), Lee=L_new(), Lep=L_new(), Lex=L_new(), Le2=L_new();
  int Lend=L_new(), Lend2=L_new();
  push_r(3); push_r(CX); push_r(DX); push_r(SI); push_r(DI);
  push_r(8); push_r(9); push_r(10); push_r(11); push_r(13);
  mv_rr(11,AX);                         /* r11 = bits */
  mv_rr(10,DI);                         /* r10 = buffer start; rdi = cursor */
  test_rr(11,11); J_cc(JC_JNS,Lpos);
  stb_rdi('-'); incdec_r(1,DI);         /* glibc prints the sign of a NaN too */
  shl_imm(11,1); shr_imm(11,1);         /* |x| */
  L_bind(Lpos);
  movq_xr(0,11); ucomisd(0,0); J_cc(0xA,Lnan);      /* jp: NaN */
  mov_imm64(AX,0x7ff0000000000000ull);
  bin_rr(0x39,11,AX); J_cc(JC_Z,Linf);  /* cmp r11, rax */
  test_rr(11,11); J_cc(JC_Z,Lzero);
  lea_rm(8,12,-1,0,(int)d_pow);         /* r8 = &pow10[0] */
  movq_xr(0,11);
  mov_imm64(AX,dbits(1.0)); movq_xr(1,AX);
  ucomisd(0,1); J_cc(JC_B,Lsmall);
  /* |x| >= 1: e = largest k with 10^k <= |x| */
  xor_rr(CX,CX);
  L_bind(Lbig);
  bin_imm32(7,CX,308); J_cc(JC_GE,Lbigdone);
  mv_r64m(AX,8,CX,3,8); movq_xr(1,AX);  /* pow10[k+1] */
  ucomisd(0,1); J_cc(JC_B,Lbigdone);
  incdec_r(1,CX); J_mp(Lbig);
  L_bind(Lbigdone);
  mv_rr(9,CX); J_mp(Lhave);
  /* |x| < 1: e = -(smallest k with |x|*10^k >= 1) */
  L_bind(Lsmall);
  mov_imm64(CX,1);
  L_bind(Lsl);
  bin_imm32(7,CX,308); J_cc(JC_GE,Lsdone);
  mv_r64m(AX,8,CX,3,0); movq_xr(1,AX);
  movq_xr(2,11); mulsd(2,1);
  mov_imm64(AX,dbits(1.0)); movq_xr(1,AX);
  ucomisd(2,1); J_cc(JC_NBE,Lsdone);    /* jae */
  incdec_r(1,CX); J_mp(Lsl);
  L_bind(Lsdone);
  mv_rr(9,CX); fm7(3,9);                /* e = -k */
  L_bind(Lhave);
  /* SCALE: rax = round(|x| * 10^(5-e)), repeated after adjusting e */
  for(int pass=0;pass<3;pass++){
    int Ln=L_new(), Lok=L_new(), Lr=L_new();
    if(pass==1){ bin_imm32(7,AX,1000000); J_cc(JC_L,Lcklow); incdec_r(1,9); }
    if(pass==2){ L_bind(Lcklow); bin_imm32(7,AX,100000); J_cc(JC_GE,Ladj); incdec_r(0,9); }
    mov_imm64(CX,5); bin_rr(0x29,CX,9);  /* s = 5 - e */
    movq_xr(0,11);
    test_rr(CX,CX); J_cc(JC_JS,Ln);
    bin_imm32(7,CX,300); J_cc(JC_LE,Lok);
    mv_r64m(AX,8,-1,0,300*8); movq_xr(1,AX); mulsd(0,1);
    bin_imm32(5,CX,300);
    L_bind(Lok);
    mv_r64m(AX,8,CX,3,0); movq_xr(1,AX); mulsd(0,1);
    J_mp(Lr);
    L_bind(Ln);
    fm7(3,CX);
    mv_r64m(AX,8,CX,3,0); movq_xr(1,AX); divsd(0,1);
    L_bind(Lr);
    cvtsd2si(AX,0);
    if(pass==1) J_mp(Ladj);
  }
  L_bind(Ladj);
  /* six digits of M into [rsp+0..5] */
  bin_imm8(5,SP,16);
  mov_imm64(CX,5);
  mov_imm64(3,10);
  L_bind(Ldg);
  xor_rr(DX,DX); fm7(6,3);              /* rax = M/10, rdx = M%10 */
  bin_imm8(0,DX,0x30);
  rexb(0,0,CX>7,0); e1(0x88); emit_modrm(DX&7,SP,0,CX,-1);   /* mov [rsp+rcx], dl */
  incdec_r(0,CX); J_cc(JC_JNS,Ldg);
  /* nd = 6 minus trailing zeros (at least 1) */
  mov_imm64(13,6);
  L_bind(Lstrip);
  bin_imm8(7,13,1); J_cc(JC_LE,Lsd);
  mv_rr(3,13); incdec_r(0,3);
  mvz_rm(AX,SP,3,0,-1);
  bin_imm8(7,AX,'0'); J_cc(JC_NZ,Lsd);
  incdec_r(0,13); J_mp(Lstrip);
  L_bind(Lsd);
  bin_imm8(7,9,(uint8_t)-4); J_cc(JC_L,Lexp);
  bin_imm8(7,9,6); J_cc(JC_GE,Lexp);
  test_rr(9,9); J_cc(JC_JS,Lfneg);
  /* fixed, e >= 0: digits 0..e, then '.' and the rest if any */
  xor_rr(CX,CX);
  L_bind(Lfi);
  mvz_rm(AX,SP,CX,0,-1); stal_rdi(); incdec_r(1,DI);
  incdec_r(1,CX); bin_rr(0x39,CX,9); J_cc(JC_LE,Lfi);
  bin_rr(0x39,CX,13); J_cc(JC_GE,Lend);
  stb_rdi('.'); incdec_r(1,DI);
  L_bind(Lff);
  mvz_rm(AX,SP,CX,0,-1); stal_rdi(); incdec_r(1,DI);
  incdec_r(1,CX); bin_rr(0x39,CX,13); J_cc(JC_L,Lff);
  J_mp(Lend);
  /* fixed, e < 0: "0." then -e-1 zeros then the digits */
  L_bind(Lfneg);
  stb_rdi('0'); incdec_r(1,DI); stb_rdi('.'); incdec_r(1,DI);
  mv_rr(CX,9); fm7(3,CX); incdec_r(0,CX);
  L_bind(Lfz);
  test_rr(CX,CX); J_cc(JC_Z,Lfzd);
  stb_rdi('0'); incdec_r(1,DI); incdec_r(0,CX); J_mp(Lfz);
  L_bind(Lfzd);
  xor_rr(CX,CX);
  L_bind(Lfd);
  mvz_rm(AX,SP,CX,0,-1); stal_rdi(); incdec_r(1,DI);
  incdec_r(1,CX); bin_rr(0x39,CX,13); J_cc(JC_L,Lfd);
  J_mp(Lend);
  /* exponential: d[.ddddd]e(+|-)XX */
  L_bind(Lexp);
  mvz_rm(AX,SP,-1,0,0); stal_rdi(); incdec_r(1,DI);
  bin_imm8(7,13,1); J_cc(JC_LE,Lee);
  stb_rdi('.'); incdec_r(1,DI);
  mov_imm64(CX,1);
  L_bind(Led);
  mvz_rm(AX,SP,CX,0,-1); stal_rdi(); incdec_r(1,DI);
  incdec_r(1,CX); bin_rr(0x39,CX,13); J_cc(JC_L,Led);
  L_bind(Lee);
  stb_rdi('e'); incdec_r(1,DI);
  mv_rr(AX,9);
  test_rr(AX,AX); J_cc(JC_JNS,Lep);
  stb_rdi('-'); incdec_r(1,DI); fm7(3,AX); J_mp(Lex);
  L_bind(Lep);
  stb_rdi('+'); incdec_r(1,DI);
  L_bind(Lex);
  bin_imm8(7,AX,100); J_cc(JC_L,Le2);
  xor_rr(DX,DX); mov_imm64(3,100); fm7(6,3);
  bin_imm8(0,AX,0x30); stal_rdi(); incdec_r(1,DI);
  mv_rr(AX,DX);
  L_bind(Le2);
  xor_rr(DX,DX); mov_imm64(3,10); fm7(6,3);
  bin_imm8(0,AX,0x30); stal_rdi(); incdec_r(1,DI);
  mv_rr(AX,DX); bin_imm8(0,AX,0x30); stal_rdi(); incdec_r(1,DI);
  L_bind(Lend);
  bin_imm8(0,SP,16);
  J_mp(Lend2);
  L_bind(Lnan);
  stb_rdi('n'); incdec_r(1,DI); stb_rdi('a'); incdec_r(1,DI); stb_rdi('n'); incdec_r(1,DI);
  J_mp(Lend2);
  L_bind(Linf);
  stb_rdi('i'); incdec_r(1,DI); stb_rdi('n'); incdec_r(1,DI); stb_rdi('f'); incdec_r(1,DI);
  J_mp(Lend2);
  L_bind(Lzero);
  stb_rdi('0'); incdec_r(1,DI);
  L_bind(Lend2);
  stb_rdi(0);
  mv_rr(AX,10);
  pop_r(13); pop_r(11); pop_r(10); pop_r(9); pop_r(8);
  pop_r(DI); pop_r(SI); pop_r(DX); pop_r(CX); pop_r(3);
  e1(0xc3);
  nlbl=0;
  }

  /* r_die: rax=msg -> stderr + exit(1) */
  {
  builtin_off[B_DIE]=cn;
  push_r(12);
  mv_rr(DI,AX);
  bin_imm8(5,SP,48);
  mv_rr(SI,SP);
  xor_rr(CX,CX);
  size_t L=cn;
  mvz_rm(AX,DI,CX,0,-1);
  test_rr(AX,AX);
  size_t jz=cn; jcc_rel32(JC_Z,0);
  rexb(0, 0, CX>7, SP>7); e1(0x88); emit_modrm(AX&7, SP, 0, CX, -1);
  incdec_r(1,CX);
  jmp_rel32((int32_t)(L-cn-5));
  size_t done=cn;
  mov_imm64(DI,2);
  mv_rr(SI,SP);
  mv_rr(DX,CX);
  mov_imm64(AX,1);
  e1(0x0f); e1(0x05);
  mov_imm64(AX,60);
  mov_imm64(DI,1);
  e1(0x0f); e1(0x05);
  bin_imm8(0,SP,48);
  pop_r(12); e1(0xc3);
  erel32(jz,done);
  }
}

/* ================= ELF ================= */
#pragma pack(push,1)
typedef struct{unsigned char i[16];uint16_t t,m;uint32_t v;uint64_t e,ph,sh;uint32_t f;uint16_t eh,ps,pn,ss,sn,si;}EH;
typedef struct{uint32_t t,f;uint64_t o,va,pa,fs,ms,a;}PH;
#pragma pack(pop)

static void write_elf(const char*path){
  /* Layout: page 0 = ELF header + program headers (R);
     page 1+ = code (RX); data on the next page after the code (RW).
     The first LOAD segment MUST start at file offset 0, and this
     kernel refuses to map a partial-page RX segment, so the code
     segment spans whole pages. */
  size_t code_off = 0x1000;
  size_t code_len = ((cn + 4095) & ~(size_t)4095);
  size_t data_off = code_off + code_len;
  size_t data_va  = BASE + data_off;
  size_t filesz = data_off + dn;
  size_t pad = (4096 - (filesz & 4095)) & 4095;
  uint8_t* img = malloc(data_off+dn+pad);
  memset(img,0,data_off+dn+pad);
  EH* eh=(EH*)img;
  eh->i[0]=0x7f; eh->i[1]='E'; eh->i[2]='L'; eh->i[3]='F';
  eh->i[4]=2; eh->i[5]=1; eh->i[6]=1;
  eh->t=2; eh->m=0x3e; eh->v=1;
  eh->e=BASE+code_off;
  eh->ph=64; eh->sh=0;
  eh->f=64; eh->eh=sizeof(EH); eh->ps=sizeof(PH); eh->pn=3;
  PH* ph=(PH*)(img+64);
  ph[0].t=1; ph[0].f=4;
  ph[0].o=0; ph[0].va=BASE; ph[0].pa=BASE;
  ph[0].fs=code_off; ph[0].ms=code_off; ph[0].a=0x1000;
  ph[1].t=1; ph[1].f=5;
  ph[1].o=code_off; ph[1].va=BASE+code_off; ph[1].pa=BASE+code_off;
  ph[1].fs=code_len; ph[1].ms=code_len; ph[1].a=0x1000;
  ph[2].t=1; ph[2].f=6;
  ph[2].o=data_off; ph[2].va=data_va; ph[2].pa=data_va;
  ph[2].fs=dn; ph[2].ms=dn; ph[2].a=0x1000;
  memcpy(img+code_off,code,cn);
  memcpy(img+data_off,data,dn);
  uint64_t cur = BASE + ((data_off+dn+4095)&~(uint64_t)4095);
  memcpy(img+data_off+OFF_CUR,&cur,8);
  { uint64_t e0=0; memcpy(img+data_off+OFF_END,&e0,8); }
  /* patch the IMAGE (relative targets are offset-invariant within it) */
  for(int i=0;i<npc;i++){
    size_t to;
    if(patch_call[i].kind==PFN){
      if(F[patch_call[i].idx].start<0){
        fprintf(stderr,"native_aot: function '%s' was called but never emitted\n",F[patch_call[i].idx].name);
        exit(1);
      }
      to=(size_t)F[patch_call[i].idx].start;
    } else to=builtin_off[patch_call[i].idx];
    int32_t d=(int32_t)(to-(patch_call[i].at+4));
    memcpy(img+code_off+patch_call[i].at,&d,4);
  }
  for(int i=0;i<npr;i++){
    int32_t d=(int32_t)(code_len-(patch_r12[i].at+4));
    memcpy(img+code_off+patch_r12[i].at,&d,4);
  }
  FILE*f=fopen(path,"wb");
  if(!f){ fprintf(stderr,"native_aot: cannot write %s\n",path); exit(1); }
  if(fwrite(img,1,data_off+dn+pad,f)!=(data_off+dn+pad)){ fprintf(stderr,"native_aot: write error\n"); exit(1); }
  fchmod(fileno(f),0755);
  fclose(f);
  free(img);
}

/* ================= main ================= */
int main(int argc,char**argv){
  if(argc<3){ fprintf(stderr,"usage: native_aot in.sa out\n"); return 2; }
  size_t sn;
  char*raw=rf(argv[1],&sn);
  char dir[2048]; const char*sl=strrchr(argv[1],'/');
  if(sl){ size_t dl=(size_t)(sl-argv[1]); if(dl>=sizeof dir) dl=sizeof dir-1; memcpy(dir,argv[1],dl); dir[dl]=0; }
  else dir[0]=0;
  char*src=expand_use(raw,sn,dir,0);
  free(raw);

  collect_defs(src);
  infer(src);

  dn=40;                /* 0,8,16,24 = cur/argv/argc/end; 32 = literal scratch */
  d_glob=d_alloc(NSLOT*8);
  d_err_div=d_str("division by zero\n");
  d_err_malloc=d_str("out of memory\n");
  d_err_list=d_str("list index out of range\n");
  d_err_str=d_str("string index out of range\n");
  d_list1=d_str("[list len=");
  d_list2=d_str("]\n");     /* seed-min/gen2 print "[list len=N]\n" */
  d_nl=d_str("\n");
  d_empty=d_str("");
  d_numbuf=d_alloc(64);
  d_pow=d_alloc(309*8);
  for(int i=0;i<=308;i++){       /* exact: strtod of "1eN" is correctly rounded */
    char t[16]; snprintf(t,sizeof t,"1e%d",i);
    double d=strtod(t,NULL); memcpy(data+d_pow+8*(size_t)i,&d,8);
  }

  /* main */
  lea_r12_data();
  /* process entry (no libc): [rsp] = argc, rsp+8 = argv[0..argc-1], NULL.
     The old code stored rdi/rsi, which are 0 at _start, so arg_count() was
     0 and arg(0) dereferenced NULL. */
  mv_r64m(AX,SP,-1,0,0);
  mv_m64(12,-1,0,OFF_ARGC,AX);
  lea_rm(AX,SP,-1,0,8);
  mv_m64(12,-1,0,OFF_ARGV,AX);
  lea_rm(DI,12,-1,0,(int)d_glob);
  mov_imm64(CX,(uint64_t)NSLOT);
  xor_rr(AX,AX);
  e1(0xf3); e1(0x48); e1(0xab);
  const char*p=src;
  emit_prog(&p,0,0);
  mov_imm64(AX,60);
  xor_rr(DI,DI);
  e1(0x0f); e1(0x05);

  /* Function bodies: emitted AFTER main's exit syscall, so main can never
     fall into them.  The walk mirrors collect_defs (same skip_stmt steps),
     so every top-level make is emitted exactly once; call sites -- in main,
     in other functions, and recursive ones -- are rel32 patches resolved in
     write_elf against F[].start, so forward references work. */
  {
    const char*q=src;
    while(*q){
      const char*line=q; sw(&q);
      if(!*q) break;
      if(q[0]=='/'&&q[1]=='/'){ while(*q&&*q!='\n') q++; continue; }
      char nm[64]; const char*r=q;
      if(mkw(&r,"make")&&pid(&r,nm,64)){
        int fi=f_find(nm);
        if(fi>=0){ q=r; emit_fn(fi,&q); continue; }
      }
      q=skip_stmt(line);
    }
  }

  emit_builtins();
  write_elf(argv[2]);
  free(src);
  return 0;
}
