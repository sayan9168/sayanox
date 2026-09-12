/*
 * Sayanox Stage-2 — generic lowering + line-numbered errors + CLI-friendly
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdarg.h>
#include <errno.h>

#define MAX_TOK 8192
#define BUF_MAX (1<<20)

typedef enum {
    T_EOF=0, T_NUMBER, T_STRING, T_IDENT,
    T_SHOW, T_HOLD, T_WHEN, T_OTHERWISE, T_WHILE, T_MAKE, T_GIVE, T_STRUCT,
    T_PLUS, T_MINUS, T_STAR, T_SLASH,
    T_EQ, T_NEQ, T_LT, T_GT, T_LTE, T_GTE, T_ASSIGN,
    T_LBRACE, T_RBRACE, T_LPAREN, T_RPAREN, T_LBRACK, T_RBRACK, T_COMMA, T_SEMI, T_DOT
} TokKind;

typedef struct { TokKind kind; char text[1024]; double num; int line; } Tok;

static char *g_src; static size_t g_len, g_pos;
static int g_line; static const char *g_path;
static Tok g_toks[MAX_TOK]; static int g_ntok, g_ti;
static int g_indent;
static char g_funcs[BUF_MAX]; static size_t g_funcs_n;
static char g_mainb[BUF_MAX]; static size_t g_main_n;
static char g_types[BUF_MAX]; static size_t g_types_n;
static int g_emit_to_func;
static char g_list_names[64][64]; static int g_nlists;
static char g_str_names[64][64]; static int g_nstrs;
static char g_decl_names[128][64]; static int g_ndecl;
static char g_struct_names[32][64]; static int g_nstruct;
static char g_struct_fields[32][8][64]; static int g_struct_nf[32];

static void die(const char *m){ fprintf(stderr,"stage2: %s:%d: error: %s\n", g_path?g_path:"input", (g_ti<g_ntok&&g_toks[g_ti].line)?g_toks[g_ti].line:g_line, m); exit(1); }
static char *read_all(const char *path){
    FILE *f=fopen(path,"rb"); if(!f){fprintf(stderr,"stage2: error: cannot open '%s'\n",path);perror("fopen");exit(1);}
    fseek(f,0,SEEK_END); long n=ftell(f); fseek(f,0,SEEK_SET);
    char *b=malloc((size_t)n+1); if(!b)exit(1);
    if(n>0)fread(b,1,(size_t)n,f); b[n]=0; fclose(f); return b;
}
static int is_id(int c){ return isalnum((unsigned char)c)||c=='_'; }
static void note_list(const char *n){ if(g_nlists<64){strncpy(g_list_names[g_nlists],n,63);g_list_names[g_nlists++][63]=0;} }
static void note_str(const char *n){ if(g_nstrs<64){strncpy(g_str_names[g_nstrs],n,63);g_str_names[g_nstrs++][63]=0;} }
static void note_decl(const char *n){ for(int i=0;i<g_ndecl;i++) if(!strcmp(g_decl_names[i],n)) return; if(g_ndecl<128){strncpy(g_decl_names[g_ndecl],n,63);g_decl_names[g_ndecl++][63]=0;} }
static int is_declared(const char *n){ for(int i=0;i<g_ndecl;i++) if(!strcmp(g_decl_names[i],n)) return 1; return 0; }
static int is_list_name(const char *n){ for(int i=0;i<g_nlists;i++) if(!strcmp(g_list_names[i],n)) return 1; return 0; }
static int is_struct_type(const char *n){ for(int i=0;i<g_nstruct;i++) if(!strcmp(g_struct_names[i],n)) return 1; return 0; }
static int struct_index(const char *n){ for(int i=0;i<g_nstruct;i++) if(!strcmp(g_struct_names[i],n)) return i; return -1; }

static void buf_printf(char *buf, size_t *n, size_t cap, const char *fmt, ...){
    if(*n>=cap-1) return; va_list ap; va_start(ap,fmt); int w=vsnprintf(buf+*n,cap-*n,fmt,ap); va_end(ap); if(w>0) *n+=(size_t)w; if(*n>=cap) *n=cap-1;
}
static void emit(const char *fmt, ...){
    char line[1024]; size_t p=0;
    for(int i=0;i<g_indent&&p+4<sizeof(line);i++){memcpy(line+p,"    ",4);p+=4;}
    va_list ap; va_start(ap,fmt); vsnprintf(line+p,sizeof(line)-p,fmt,ap); va_end(ap);
    if(g_emit_to_func) buf_printf(g_funcs,&g_funcs_n,BUF_MAX,"%s",line);
    else buf_printf(g_mainb,&g_main_n,BUF_MAX,"%s",line);
}

static void lex(void){
    g_ntok=0; g_pos=0; g_line=1;
    while(g_pos<g_len && g_ntok<MAX_TOK-1){
        char c=g_src[g_pos];
        if(c=='\n'){g_line++; g_pos++; continue;}
        if(c==' '||c=='\t'||c=='\r'){g_pos++;continue;}
        if(c=='/'&&g_pos+1<g_len&&g_src[g_pos+1]=='/'){while(g_pos<g_len&&g_src[g_pos]!='\n')g_pos++;continue;}
        Tok *t=&g_toks[g_ntok]; memset(t,0,sizeof(*t)); t->line=g_line;
        if(isdigit((unsigned char)c)){
            double v=0; while(g_pos<g_len&&isdigit((unsigned char)g_src[g_pos])){v=v*10+(g_src[g_pos]-'0');g_pos++;}
            t->kind=T_NUMBER; t->num=v; snprintf(t->text,sizeof(t->text),"%g",v); g_ntok++; continue;
        }
        if(c=='"'){
            g_pos++; size_t n=0;
            while(g_pos<g_len){
                if(g_src[g_pos]=='\\'){
                    g_pos++; if(g_pos>=g_len) break;
                    char e=g_src[g_pos++]; char out=e;
                    if(e=='n') out='\n'; else if(e=='t') out='\t'; else if(e=='r') out='\r';
                    if(n+1<sizeof(t->text)) t->text[n++]=out; continue;
                }
                if(g_src[g_pos]=='"'){ g_pos++; break; }
                if(g_src[g_pos]=='\n') g_line++;
                if(n+1<sizeof(t->text)) t->text[n++]=g_src[g_pos];
                g_pos++;
            }
            t->text[n]=0; t->kind=T_STRING; g_ntok++; continue;
        }
        if(isalpha((unsigned char)c)||c=='_'){
            size_t n=0; while(g_pos<g_len&&is_id((unsigned char)g_src[g_pos])){if(n+1<sizeof(t->text))t->text[n++]=g_src[g_pos];g_pos++;}
            t->text[n]=0;
            if(!strcmp(t->text,"show"))t->kind=T_SHOW;
            else if(!strcmp(t->text,"hold"))t->kind=T_HOLD;
            else if(!strcmp(t->text,"when"))t->kind=T_WHEN;
            else if(!strcmp(t->text,"otherwise"))t->kind=T_OTHERWISE;
            else if(!strcmp(t->text,"while"))t->kind=T_WHILE;
            else if(!strcmp(t->text,"make"))t->kind=T_MAKE;
            else if(!strcmp(t->text,"give"))t->kind=T_GIVE;
            else if(!strcmp(t->text,"struct"))t->kind=T_STRUCT;
            else t->kind=T_IDENT;
            g_ntok++; continue;
        }
        if(c=='='&&g_pos+1<g_len&&g_src[g_pos+1]=='='){t->kind=T_EQ;strcpy(t->text,"==");g_pos+=2;g_ntok++;continue;}
        if(c=='!'&&g_pos+1<g_len&&g_src[g_pos+1]=='='){t->kind=T_NEQ;strcpy(t->text,"!=");g_pos+=2;g_ntok++;continue;}
        if(c=='<'&&g_pos+1<g_len&&g_src[g_pos+1]=='='){t->kind=T_LTE;strcpy(t->text,"<=");g_pos+=2;g_ntok++;continue;}
        if(c=='>'&&g_pos+1<g_len&&g_src[g_pos+1]=='='){t->kind=T_GTE;strcpy(t->text,">=");g_pos+=2;g_ntok++;continue;}
        switch(c){
            case '+':t->kind=T_PLUS;break;case '-':t->kind=T_MINUS;break;
            case '*':t->kind=T_STAR;break;case '/':t->kind=T_SLASH;break;
            case '=':t->kind=T_ASSIGN;break;case '<':t->kind=T_LT;break;case '>':t->kind=T_GT;break;
            case '{':t->kind=T_LBRACE;break;case '}':t->kind=T_RBRACE;break;
            case '(':t->kind=T_LPAREN;break;case ')':t->kind=T_RPAREN;break;
            case '[':t->kind=T_LBRACK;break;case ']':t->kind=T_RBRACK;break;
            case ',':t->kind=T_COMMA;break;case ';':t->kind=T_SEMI;break;case '.':t->kind=T_DOT;break;
            default: fprintf(stderr,"stage2: %s:%d: error: unexpected character '%c'\n", g_path?g_path:"input", g_line, c); exit(1);
        }
        t->text[0]=c;t->text[1]=0;g_pos++;g_ntok++;
    }
    g_toks[g_ntok].kind=T_EOF; g_toks[g_ntok].line=g_line; g_ti=0;
}

static Tok *cur(void){return &g_toks[g_ti];}
static Tok *advance(void){if(g_ti<g_ntok)g_ti++;return cur();}
static int check(TokKind k){return cur()->kind==k;}
static int match(TokKind k){if(check(k)){advance();return 1;}return 0;}
static void expect(TokKind k,const char *msg){
    if(!match(k)){
        fprintf(stderr,"stage2: %s:%d: error: expected %s, got '%s'\n",
            g_path?g_path:"input", cur()->line, msg, cur()->text[0]?cur()->text:"EOF");
        exit(1);
    }
}

static char *parse_expr(void);
static char *parse_primary(void){
    char *buf=malloc(900); if(!buf)exit(1); buf[0]=0;
    if(match(T_LBRACK)){
        if(match(T_RBRACK)){snprintf(buf,900,"sx_list_new()");return buf;}
        char *tmp=malloc(900); snprintf(tmp,900,"({SxList __l=sx_list_new();");
        char *e=parse_expr(); char piece[220];
        snprintf(piece,sizeof(piece)," sx_list_push(&__l,%s);",e); free(e); strncat(tmp,piece,900-strlen(tmp)-1);
        while(match(T_COMMA)){ e=parse_expr(); snprintf(piece,sizeof(piece)," sx_list_push(&__l,%s);",e); free(e); strncat(tmp,piece,900-strlen(tmp)-1); }
        expect(T_RBRACK,"]"); strncat(tmp," __l;})",900-strlen(tmp)-1); free(buf); return tmp;
    }
    if(check(T_NUMBER)){snprintf(buf,900,"%g",cur()->num);advance();return buf;}
    if(check(T_STRING)){
        char esc[900]; size_t ei=0; const char *s=cur()->text;
        esc[ei++]='"';
        for(;*s && ei+4<sizeof(esc);s++){
            if(*s=='"'||*s=='\\'){ esc[ei++]='\\'; esc[ei++]=*s; }
            else if(*s=='\n'){ esc[ei++]='\\'; esc[ei++]='n'; }
            else if(*s=='\t'){ esc[ei++]='\\'; esc[ei++]='t'; }
            else esc[ei++]=*s;
        }
        esc[ei++]='"'; esc[ei]=0;
        snprintf(buf,900,"%s",esc); advance(); return buf;
    }
    if(check(T_IDENT)){
        snprintf(buf,900,"%s",cur()->text); advance();
        if(is_struct_type(buf) && check(T_LBRACE)){
            int si=struct_index(buf); advance();
            char *tmp=malloc(900); snprintf(tmp,900,"((%s){",buf); int fi=0;
            if(!check(T_RBRACE)){
                char *e=parse_expr(); char piece[220];
                if(si>=0&&fi<g_struct_nf[si]) snprintf(piece,sizeof(piece),".%s=%s",g_struct_fields[si][fi],e);
                else snprintf(piece,sizeof(piece),"%s",e);
                free(e); strncat(tmp,piece,900-strlen(tmp)-1); fi++;
                while(match(T_COMMA)){
                    e=parse_expr();
                    if(si>=0&&fi<g_struct_nf[si]) snprintf(piece,sizeof(piece),", .%s=%s",g_struct_fields[si][fi],e);
                    else snprintf(piece,sizeof(piece),", %s",e);
                    free(e); strncat(tmp,piece,900-strlen(tmp)-1); fi++;
                }
            }
            expect(T_RBRACE,"}"); strncat(tmp,"})",900-strlen(tmp)-1); free(buf); return tmp;
        }
        while(match(T_DOT)){
            if(!check(T_IDENT)) die("expected field name after '.'");
            char *n=malloc(900); snprintf(n,900,"%s.%s",buf,cur()->text); advance(); free(buf); buf=n;
        }
        if(match(T_LBRACK)){
            char *ix=parse_expr(); expect(T_RBRACK,"]");
            char *n=malloc(900);
            if(is_list_name(buf)) snprintf(n,900,"sx_list_get(&%s,(int)(%s))",buf,ix);
            else snprintf(n,900,"((double)((unsigned char)%s[(int)(%s)]))",buf,ix);
            free(buf); free(ix); return n;
        }
        if(match(T_LPAREN)){
            char args[500]="";
            if(!check(T_RPAREN)){
                char *a=parse_expr(); strncat(args,a,sizeof(args)-1); free(a);
                while(match(T_COMMA)){strncat(args,", ",sizeof(args)-1);a=parse_expr();strncat(args,a,sizeof(args)-1);free(a);}
            }
            expect(T_RPAREN,")");
            char *call=malloc(900);
            if(!strcmp(buf,"str")) snprintf(call,900,"sx_str(%s)",args);
            else if(!strcmp(buf,"len")){
                if(strchr(args,'"')==NULL&&strchr(args,'(')==NULL&&is_list_name(args))
                    snprintf(call,900,"((double)sx_list_len(&%s))",args);
                else if(strchr(args,'"')==NULL&&strchr(args,'(')==NULL)
                    snprintf(call,900,"((double)strlen(%s))",args);
                else snprintf(call,900,"sx_len_any(%s)",args);
            }
            else if(!strcmp(buf,"list_len")) snprintf(call,900,"((double)sx_list_len(&%s))",args);
            else if(!strcmp(buf,"concat")) snprintf(call,900,"sx_concat(%s)",args);
            else if(!strcmp(buf,"read_file")) snprintf(call,900,"sx_read_file(%s)",args);
            else if(!strcmp(buf,"write_file")) snprintf(call,900,"sx_write_file(%s)",args);
            else if(!strcmp(buf,"push")) snprintf(call,900,"(sx_list_push(&%s),0.0)",args);
            else snprintf(call,900,"sx_%s(%s)",buf,args);
            free(buf); return call;
        }
        return buf;
    }
    if(match(T_LPAREN)){char *e=parse_expr();expect(T_RPAREN,")");snprintf(buf,900,"(%s)",e);free(e);return buf;}
    if(match(T_MINUS)){char *e=parse_primary();snprintf(buf,900,"(-%s)",e);free(e);return buf;}
    die("expected expression"); return buf;
}
static char *parse_term(void){
    char *left=parse_primary();
    while(check(T_STAR)||check(T_SLASH)){
        char op=check(T_STAR)?'*':'/'; advance(); char *right=parse_primary();
        char *n=malloc(900); snprintf(n,900,"(%s %c %s)",left,op,right); free(left);free(right); left=n;
    } return left;
}
static char *parse_add(void){
    char *left=parse_term();
    while(check(T_PLUS)||check(T_MINUS)){
        char op=check(T_PLUS)?'+':'-'; advance(); char *right=parse_term();
        char *n=malloc(900); snprintf(n,900,"(%s %c %s)",left,op,right); free(left);free(right); left=n;
    } return left;
}
static char *parse_cmp(void){
    char *left=parse_add();
    if(check(T_EQ)||check(T_NEQ)||check(T_LT)||check(T_GT)||check(T_LTE)||check(T_GTE)){
        const char *op=cur()->text; advance(); char *right=parse_add();
        char *n=malloc(900); snprintf(n,900,"(%s %s %s)",left,op,right); free(left);free(right); return n;
    } return left;
}
static char *parse_expr(void){ return parse_cmp(); }
static void parse_block(void);
static int looks_string(const char *e){ if(!e)return 0; if(e[0]=='"')return 1; return strstr(e,"sx_str")||strstr(e,"sx_concat")||strstr(e,"sx_read_file")?1:0; }
static int looks_list(const char *e){ return e&&(strstr(e,"sx_list_new")||strstr(e,"SxList")); }
static int looks_struct(const char *e){ if(!e)return 0; for(int i=0;i<g_nstruct;i++){ char pat[80]; snprintf(pat,sizeof(pat),"((%s)",g_struct_names[i]); if(strstr(e,pat)) return 1; } return 0; }
static const char *struct_type_of_expr(const char *e){ for(int i=0;i<g_nstruct;i++){ char pat[80]; snprintf(pat,sizeof(pat),"((%s)",g_struct_names[i]); if(strstr(e,pat)) return g_struct_names[i]; } return NULL; }

static void parse_stmt(void){
    if(check(T_EOF)||check(T_RBRACE)) return;
    if(match(T_STRUCT)){
        if(!check(T_IDENT)) die("expected struct name");
        char sname[64]; strncpy(sname,cur()->text,63); sname[63]=0; advance();
        expect(T_LBRACE,"{"); int si=g_nstruct;
        if(si<32){ strncpy(g_struct_names[si],sname,63); g_struct_names[si][63]=0; g_struct_nf[si]=0; }
        buf_printf(g_types,&g_types_n,BUF_MAX,"typedef struct {\n");
        while(!check(T_RBRACE)&&!check(T_EOF)){
            if(check(T_IDENT)){
                if(si<32&&g_struct_nf[si]<8){strncpy(g_struct_fields[si][g_struct_nf[si]],cur()->text,63);g_struct_fields[si][g_struct_nf[si]][63]=0;g_struct_nf[si]++;}
                buf_printf(g_types,&g_types_n,BUF_MAX,"  double %s;\n",cur()->text); advance(); match(T_COMMA);
            } else advance();
        }
        expect(T_RBRACE,"}"); buf_printf(g_types,&g_types_n,BUF_MAX,"} %s;\n\n",sname); if(si<32) g_nstruct++; return;
    }
    if(match(T_SHOW)){
        char *e=parse_expr();
        if(looks_string(e)) emit("printf(\"%%s\\n\", %s);\n",e);
        else emit("printf(\"%%g\\n\", (double)(%s));\n",e);
        free(e); match(T_SEMI); return;
    }
    if(match(T_HOLD)){
        if(!check(T_IDENT)) die("expected name after hold");
        char name[128]; strncpy(name,cur()->text,sizeof(name)-1); name[sizeof(name)-1]=0; advance();
        expect(T_ASSIGN,"="); char *e=parse_expr();
        if(is_declared(name)) emit("%s = %s;\n",name,e);
        else {
            note_decl(name);
            if(looks_list(e)){ emit("SxList %s = %s;\n",name,e); note_list(name); }
            else if(looks_string(e)){ emit("char *%s = %s;\n",name,e); note_str(name); }
            else if(looks_struct(e)){ const char *ty=struct_type_of_expr(e); emit("%s %s = %s;\n",ty?ty:"double",name,e); }
            else emit("double %s = %s;\n",name,e);
        }
        free(e); match(T_SEMI); return;
    }
    if(match(T_WHEN)){
        char *cond=parse_expr(); emit("if (%s) {\n",cond); free(cond); g_indent++;
        expect(T_LBRACE,"{"); parse_block(); expect(T_RBRACE,"}"); g_indent--; emit("}\n");
        if(match(T_OTHERWISE)){ emit("else {\n"); g_indent++; expect(T_LBRACE,"{"); parse_block(); expect(T_RBRACE,"}"); g_indent--; emit("}\n"); }
        return;
    }
    if(match(T_WHILE)){
        char *cond=parse_expr(); emit("while (%s) {\n",cond); free(cond); g_indent++;
        expect(T_LBRACE,"{"); parse_block(); expect(T_RBRACE,"}"); g_indent--; emit("}\n"); return;
    }
    if(match(T_GIVE)){ char *e=parse_expr(); emit("return %s;\n",e); free(e); match(T_SEMI); return; }
    if(match(T_MAKE)){
        if(!check(T_IDENT)) die("expected function name after make");
        char fname[128]; strncpy(fname,cur()->text,sizeof(fname)-1); fname[sizeof(fname)-1]=0; advance();
        char params[400]=""; expect(T_LPAREN,"(");
        if(check(T_IDENT)){ strncat(params,"double ",sizeof(params)-1); strncat(params,cur()->text,sizeof(params)-1); advance();
            while(match(T_COMMA)){ if(!check(T_IDENT)) break; strncat(params,", double ",sizeof(params)-1); strncat(params,cur()->text,sizeof(params)-1); advance(); } }
        expect(T_RPAREN,")");
        int saved=g_emit_to_func; g_emit_to_func=1;
        buf_printf(g_funcs,&g_funcs_n,BUF_MAX,"double sx_%s(%s) {\n",fname,params);
        g_indent=1; expect(T_LBRACE,"{"); parse_block(); expect(T_RBRACE,"}"); emit("return 0.0;\n"); g_indent=0;
        buf_printf(g_funcs,&g_funcs_n,BUF_MAX,"}\n\n"); g_emit_to_func=saved; return;
    }
    if(check(T_IDENT)){ char *e=parse_expr(); emit("%s;\n",e); free(e); match(T_SEMI); return; }
    fprintf(stderr,"stage2: %s:%d: error: unexpected token '%s'\n", g_path?g_path:"input", cur()->line, cur()->text);
    exit(1);
}
static void parse_block(void){ while(!check(T_RBRACE)&&!check(T_EOF)) parse_stmt(); }

static const char *RUNTIME =
"typedef struct { double *data; int len; int cap; } SxList;\n"
"static SxList sx_list_new(void){ SxList l; l.data=NULL; l.len=0; l.cap=0; return l; }\n"
"static void sx_list_push(SxList *l, double v){\n"
"  if(l->len>=l->cap){ int n=l->cap?l->cap*2:8; double *d=realloc(l->data,sizeof(double)*n); if(!d)exit(1); l->data=d; l->cap=n; }\n"
"  l->data[l->len++]=v;\n}\n"
"static double sx_list_get(SxList *l, int i){ if(i<0||i>=l->len){fprintf(stderr,\"index\\n\");exit(1);} return l->data[i]; }\n"
"static int sx_list_len(SxList *l){ return l->len; }\n"
"static char *sx_concat(const char *a, const char *b){\n"
"  size_t la=strlen(a),lb=strlen(b); char *r=malloc(la+lb+1); if(!r)exit(1); memcpy(r,a,la); memcpy(r+la,b,lb); r[la+lb]=0; return r;\n}\n"
"static char *sx_str(double n){ char *b=malloc(64); if(!b)exit(1); snprintf(b,64,\"%g\",n); return b; }\n"
"static char *sx_read_file(const char *path){\n"
"  FILE *f=fopen(path,\"rb\"); if(!f){fprintf(stderr,\"cannot open %s\\n\",path);exit(1);}\n"
"  fseek(f,0,SEEK_END); long n=ftell(f); fseek(f,0,SEEK_SET);\n"
"  char *b=malloc((size_t)n+1); if(!b)exit(1); if(n>0)fread(b,1,(size_t)n,f); b[n]=0; fclose(f); return b;\n}\n"
"static double sx_write_file(const char *path, const char *data){\n"
"  FILE *f=fopen(path,\"wb\"); if(!f){fprintf(stderr,\"cannot write %s\\n\",path);exit(1);} fputs(data,f); fclose(f); return 0.0;\n}\n"
"static double sx_len_any(const char *s){ return (double)strlen(s); }\n\n";

static void compile_generic(const char *out_path){
    lex();
    g_funcs_n=0; g_main_n=0; g_types_n=0; g_funcs[0]=0; g_mainb[0]=0; g_types[0]=0;
    g_nlists=0; g_nstrs=0; g_ndecl=0; g_nstruct=0; g_emit_to_func=0; g_indent=1;
    while(!check(T_EOF)) parse_stmt();
    FILE *o=fopen(out_path,"wb");
    if(!o){ fprintf(stderr,"stage2: error: cannot write '%s'\n", out_path); perror("fopen"); exit(1); }
    fputs("/* Generated by Sayanox Stage-2 GENERIC */\n",o);
    fputs("#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n\n",o);
    fputs(RUNTIME,o); fputs(g_types,o); fputs(g_funcs,o);
    fputs("int main(void) {\n",o); fputs(g_mainb,o); fputs("    return 0;\n}\n",o);
    fclose(o);
}

int main(int argc,char **argv){
    const char *in="selfhost/hello.sa"; const char *out="selfhost/stage2_out.c";
    if(argc>=2)in=argv[1]; if(argc>=3)out=argv[2];
    if(argc>=2 && (!strcmp(argv[1],"-h")||!strcmp(argv[1],"--help"))){
        fprintf(stderr,"Usage: stage2 <input.sa> [output.c]\n");
        return 0;
    }
    g_path=in; g_src=read_all(in); g_len=strlen(g_src);
    compile_generic(out);
    printf("stage2: ok %s -> %s (%d tokens)\n",in,out,g_ntok);
    free(g_src); return 0;
}
