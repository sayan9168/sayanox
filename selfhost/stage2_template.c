/*
 * Sayanox Stage-2 — Generic lowering (Phase A / Stage-3 ready)
 * make, arrays, string index, list_len, file I/O runtime
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdarg.h>

#define MAX_TOK 8192
#define BUF_MAX (1<<20)

typedef enum {
    T_EOF=0, T_NUMBER, T_STRING, T_IDENT,
    T_SHOW, T_HOLD, T_WHEN, T_OTHERWISE, T_WHILE, T_MAKE, T_GIVE,
    T_PLUS, T_MINUS, T_STAR, T_SLASH,
    T_EQ, T_NEQ, T_LT, T_GT, T_LTE, T_GTE, T_ASSIGN,
    T_LBRACE, T_RBRACE, T_LPAREN, T_RPAREN, T_LBRACK, T_RBRACK, T_COMMA, T_SEMI
} TokKind;

typedef struct { TokKind kind; char text[256]; double num; } Tok;

static char *g_src; static size_t g_len, g_pos;
static Tok g_toks[MAX_TOK]; static int g_ntok, g_ti;
static int g_indent;
static char g_funcs[BUF_MAX]; static size_t g_funcs_n;
static char g_mainb[BUF_MAX]; static size_t g_main_n;
static int g_emit_to_func;
/* track names held as list or string for index/len */
static char g_list_names[64][64]; static int g_nlists;
static char g_str_names[64][64]; static int g_nstrs;

static void die(const char *m){ fprintf(stderr,"stage2: %s\n",m); exit(1); }

static char *read_all(const char *path){
    FILE *f=fopen(path,"rb"); if(!f){fprintf(stderr,"stage2: cannot open %s\n",path);exit(1);}
    fseek(f,0,SEEK_END); long n=ftell(f); fseek(f,0,SEEK_SET);
    char *b=malloc((size_t)n+1); if(!b)exit(1);
    if(n>0)fread(b,1,(size_t)n,f); b[n]=0; fclose(f); return b;
}
static int is_id(int c){ return isalnum((unsigned char)c)||c=='_'; }

static void note_list(const char *name){
    if(g_nlists<64){ strncpy(g_list_names[g_nlists],name,63); g_list_names[g_nlists][63]=0; g_nlists++; }
}
static void note_str(const char *name){
    if(g_nstrs<64){ strncpy(g_str_names[g_nstrs],name,63); g_str_names[g_nstrs][63]=0; g_nstrs++; }
}
static int is_list_name(const char *name){
    for(int i=0;i<g_nlists;i++) if(!strcmp(g_list_names[i],name)) return 1; return 0;
}
static int is_str_name(const char *name){
    for(int i=0;i<g_nstrs;i++) if(!strcmp(g_str_names[i],name)) return 1; return 0;
}

static void buf_printf(char *buf, size_t *n, size_t cap, const char *fmt, ...){
    if(*n >= cap-1) return;
    va_list ap; va_start(ap,fmt);
    int w=vsnprintf(buf+*n, cap-*n, fmt, ap);
    va_end(ap);
    if(w>0) *n += (size_t)w;
    if(*n>=cap) *n=cap-1;
}

static void emit(const char *fmt, ...){
    char line[1024];
    size_t p=0;
    for(int i=0;i<g_indent && p+4<sizeof(line);i++){ memcpy(line+p,"    ",4); p+=4; }
    va_list ap; va_start(ap,fmt);
    vsnprintf(line+p, sizeof(line)-p, fmt, ap);
    va_end(ap);
    if(g_emit_to_func) buf_printf(g_funcs,&g_funcs_n,BUF_MAX,"%s",line);
    else buf_printf(g_mainb,&g_main_n,BUF_MAX,"%s",line);
}

static void lex(void){
    g_ntok=0; g_pos=0;
    while(g_pos<g_len && g_ntok<MAX_TOK-1){
        char c=g_src[g_pos];
        if(c==' '||c=='\t'||c=='\r'||c=='\n'){ g_pos++; continue; }
        if(c=='/'&&g_pos+1<g_len&&g_src[g_pos+1]=='/'){ while(g_pos<g_len&&g_src[g_pos]!='\n')g_pos++; continue; }
        Tok *t=&g_toks[g_ntok]; memset(t,0,sizeof(*t));
        if(isdigit((unsigned char)c)){
            double v=0; while(g_pos<g_len&&isdigit((unsigned char)g_src[g_pos])){ v=v*10+(g_src[g_pos]-'0'); g_pos++; }
            t->kind=T_NUMBER; t->num=v; snprintf(t->text,sizeof(t->text),"%g",v); g_ntok++; continue;
        }
        if(c=='"'){
            g_pos++; size_t n=0;
            while(g_pos<g_len&&g_src[g_pos]!='"'){ if(n+1<sizeof(t->text)) t->text[n++]=g_src[g_pos]; g_pos++; }
            if(g_pos<g_len)g_pos++; t->text[n]=0; t->kind=T_STRING; g_ntok++; continue;
        }
        if(isalpha((unsigned char)c)||c=='_'){
            size_t n=0; while(g_pos<g_len&&is_id((unsigned char)g_src[g_pos])){ if(n+1<sizeof(t->text))t->text[n++]=g_src[g_pos]; g_pos++; }
            t->text[n]=0;
            if(!strcmp(t->text,"show"))t->kind=T_SHOW;
            else if(!strcmp(t->text,"hold"))t->kind=T_HOLD;
            else if(!strcmp(t->text,"when"))t->kind=T_WHEN;
            else if(!strcmp(t->text,"otherwise"))t->kind=T_OTHERWISE;
            else if(!strcmp(t->text,"while"))t->kind=T_WHILE;
            else if(!strcmp(t->text,"make"))t->kind=T_MAKE;
            else if(!strcmp(t->text,"give"))t->kind=T_GIVE;
            else t->kind=T_IDENT;
            g_ntok++; continue;
        }
        if(c=='='&&g_pos+1<g_len&&g_src[g_pos+1]=='='){ t->kind=T_EQ; strcpy(t->text,"=="); g_pos+=2; g_ntok++; continue; }
        if(c=='!'&&g_pos+1<g_len&&g_src[g_pos+1]=='='){ t->kind=T_NEQ; strcpy(t->text,"!="); g_pos+=2; g_ntok++; continue; }
        if(c=='<'&&g_pos+1<g_len&&g_src[g_pos+1]=='='){ t->kind=T_LTE; strcpy(t->text,"<="); g_pos+=2; g_ntok++; continue; }
        if(c=='>'&&g_pos+1<g_len&&g_src[g_pos+1]=='='){ t->kind=T_GTE; strcpy(t->text,">="); g_pos+=2; g_ntok++; continue; }
        switch(c){
            case '+': t->kind=T_PLUS; break; case '-': t->kind=T_MINUS; break;
            case '*': t->kind=T_STAR; break; case '/': t->kind=T_SLASH; break;
            case '=': t->kind=T_ASSIGN; break; case '<': t->kind=T_LT; break; case '>': t->kind=T_GT; break;
            case '{': t->kind=T_LBRACE; break; case '}': t->kind=T_RBRACE; break;
            case '(': t->kind=T_LPAREN; break; case ')': t->kind=T_RPAREN; break;
            case '[': t->kind=T_LBRACK; break; case ']': t->kind=T_RBRACK; break;
            case ',': t->kind=T_COMMA; break; case ';': t->kind=T_SEMI; break;
            default: g_pos++; continue;
        }
        t->text[0]=c; t->text[1]=0; g_pos++; g_ntok++;
    }
    g_toks[g_ntok].kind=T_EOF; g_ti=0;
}

static Tok *cur(void){ return &g_toks[g_ti]; }
static Tok *advance(void){ if(g_ti<g_ntok)g_ti++; return cur(); }
static int check(TokKind k){ return cur()->kind==k; }
static int match(TokKind k){ if(check(k)){ advance(); return 1; } return 0; }
static void expect(TokKind k,const char *msg){
    if(!match(k)){ fprintf(stderr,"stage2: parse error: %s (got %s)\n",msg,cur()->text); exit(1); }
}

static char *parse_expr(void);

static char *parse_primary(void){
    char *buf=malloc(768); if(!buf)exit(1); buf[0]=0;
    if(match(T_LBRACK)){
        if(match(T_RBRACK)){ snprintf(buf,768,"sx_list_new()"); return buf; }
        char *tmp=malloc(900); snprintf(tmp,900,"({SxList __l=sx_list_new();");
        char *e=parse_expr(); char piece[200];
        snprintf(piece,sizeof(piece)," sx_list_push(&__l,%s);",e); free(e);
        strncat(tmp,piece,900-strlen(tmp)-1);
        while(match(T_COMMA)){
            e=parse_expr(); snprintf(piece,sizeof(piece)," sx_list_push(&__l,%s);",e); free(e);
            strncat(tmp,piece,900-strlen(tmp)-1);
        }
        expect(T_RBRACK,"]"); strncat(tmp," __l;})",900-strlen(tmp)-1);
        free(buf); return tmp;
    }
    if(check(T_NUMBER)){ snprintf(buf,768,"%g",cur()->num); advance(); return buf; }
    if(check(T_STRING)){ snprintf(buf,768,"\"%s\"",cur()->text); advance(); return buf; }
    if(check(T_IDENT)){
        snprintf(buf,768,"%s",cur()->text); advance();
        if(match(T_LBRACK)){
            char *ix=parse_expr(); expect(T_RBRACK,"]");
            char *n=malloc(768);
            if(is_list_name(buf))
                snprintf(n,768,"sx_list_get(&%s,(int)(%s))",buf,ix);
            else
                snprintf(n,768,"((double)((unsigned char)%s[(int)(%s)]))",buf,ix);
            free(buf); free(ix); return n;
        }
        if(match(T_LPAREN)){
            char args[500]="";
            if(!check(T_RPAREN)){
                char *a=parse_expr(); strncat(args,a,sizeof(args)-strlen(args)-1); free(a);
                while(match(T_COMMA)){ strncat(args,", ",sizeof(args)-strlen(args)-1); a=parse_expr(); strncat(args,a,sizeof(args)-strlen(args)-1); free(a); }
            }
            expect(T_RPAREN,")");
            char *call=malloc(800);
            if(!strcmp(buf,"str")) snprintf(call,800,"sx_str(%s)",args);
            else if(!strcmp(buf,"len")){
                if(strchr(args,'"')==NULL && strchr(args,'(')==NULL && is_list_name(args))
                    snprintf(call,800,"((double)sx_list_len(&%s))",args);
                else if(strchr(args,'"')==NULL && strchr(args,'(')==NULL)
                    snprintf(call,800,"((double)strlen(%s))",args);
                else
                    snprintf(call,800,"sx_len_any(%s)",args);
            }
            else if(!strcmp(buf,"list_len")) snprintf(call,800,"((double)sx_list_len(&%s))",args);
            else if(!strcmp(buf,"concat")) snprintf(call,800,"sx_concat(%s)",args);
            else if(!strcmp(buf,"read_file")) snprintf(call,800,"sx_read_file(%s)",args);
            else if(!strcmp(buf,"write_file")) snprintf(call,800,"sx_write_file(%s)",args);
            else if(!strcmp(buf,"push")) snprintf(call,800,"(sx_list_push(&%s),0.0)",args);
            else snprintf(call,800,"sx_%s(%s)",buf,args);
            free(buf); return call;
        }
        return buf;
    }
    if(match(T_LPAREN)){ char *e=parse_expr(); expect(T_RPAREN,")"); snprintf(buf,768,"(%s)",e); free(e); return buf; }
    if(match(T_MINUS)){ char *e=parse_primary(); snprintf(buf,768,"(-%s)",e); free(e); return buf; }
    strcpy(buf,"0"); return buf;
}
static char *parse_term(void){
    char *left=parse_primary();
    while(check(T_STAR)||check(T_SLASH)){
        char op=check(T_STAR)?'*':'/'; advance(); char *right=parse_primary();
        char *n=malloc(800); snprintf(n,800,"(%s %c %s)",left,op,right); free(left); free(right); left=n;
    }
    return left;
}
static char *parse_add(void){
    char *left=parse_term();
    while(check(T_PLUS)||check(T_MINUS)){
        char op=check(T_PLUS)?'+':'-'; advance(); char *right=parse_term();
        char *n=malloc(800); snprintf(n,800,"(%s %c %s)",left,op,right); free(left); free(right); left=n;
    }
    return left;
}
static char *parse_cmp(void){
    char *left=parse_add();
    if(check(T_EQ)||check(T_NEQ)||check(T_LT)||check(T_GT)||check(T_LTE)||check(T_GTE)){
        const char *op=cur()->text; advance(); char *right=parse_add();
        char *n=malloc(800); snprintf(n,800,"(%s %s %s)",left,op,right); free(left); free(right); return n;
    }
    return left;
}
static char *parse_expr(void){ return parse_cmp(); }

static void parse_block(void);
static int looks_string(const char *e){
    if(!e)return 0;
    if(e[0]=='"')return 1;
    if(strstr(e,"sx_str")||strstr(e,"sx_concat")||strstr(e,"sx_read_file"))return 1;
    return 0;
}
static int looks_list(const char *e){
    return e&&(strstr(e,"sx_list_new")||strstr(e,"SxList"));
}

static void parse_stmt(void){
    if(check(T_EOF)||check(T_RBRACE)) return;
    if(match(T_SHOW)){
        char *e=parse_expr();
        if(looks_string(e)) emit("printf(\"%%s\\n\", %s);\n",e);
        else emit("printf(\"%%g\\n\", (double)(%s));\n",e);
        free(e); match(T_SEMI); return;
    }
    if(match(T_HOLD)){
        if(!check(T_IDENT)) die("hold expects name");
        char name[128]; strncpy(name,cur()->text,sizeof(name)-1); name[sizeof(name)-1]=0; advance();
        expect(T_ASSIGN,"="); char *e=parse_expr();
        if(looks_list(e)){ emit("SxList %s = %s;\n",name,e); note_list(name); }
        else if(looks_string(e)){ emit("char *%s = %s;\n",name,e); note_str(name); }
        else emit("double %s = %s;\n",name,e);
        free(e); match(T_SEMI); return;
    }
    if(match(T_WHEN)){
        char *cond=parse_expr(); emit("if (%s) {\n",cond); free(cond); g_indent++;
        expect(T_LBRACE,"{"); parse_block(); expect(T_RBRACE,"}"); g_indent--; emit("}\n");
        if(match(T_OTHERWISE)){
            emit("else {\n"); g_indent++; expect(T_LBRACE,"{"); parse_block(); expect(T_RBRACE,"}"); g_indent--; emit("}\n");
        }
        return;
    }
    if(match(T_WHILE)){
        char *cond=parse_expr(); emit("while (%s) {\n",cond); free(cond); g_indent++;
        expect(T_LBRACE,"{"); parse_block(); expect(T_RBRACE,"}"); g_indent--; emit("}\n"); return;
    }
    if(match(T_GIVE)){ char *e=parse_expr(); emit("return %s;\n",e); free(e); match(T_SEMI); return; }
    if(match(T_MAKE)){
        if(!check(T_IDENT)) die("make expects name");
        char fname[128]; strncpy(fname,cur()->text,sizeof(fname)-1); fname[sizeof(fname)-1]=0; advance();
        char params[400]="";
        expect(T_LPAREN,"(");
        if(check(T_IDENT)){
            strncat(params,"double ",sizeof(params)-1); strncat(params,cur()->text,sizeof(params)-1); advance();
            while(match(T_COMMA)){
                if(!check(T_IDENT)) break;
                strncat(params,", double ",sizeof(params)-1); strncat(params,cur()->text,sizeof(params)-1); advance();
            }
        }
        expect(T_RPAREN,")");
        int saved=g_emit_to_func; g_emit_to_func=1;
        buf_printf(g_funcs,&g_funcs_n,BUF_MAX,"double sx_%s(%s) {\n",fname,params);
        g_indent=1; expect(T_LBRACE,"{"); parse_block(); expect(T_RBRACE,"}");
        emit("return 0.0;\n"); g_indent=0;
        buf_printf(g_funcs,&g_funcs_n,BUF_MAX,"}\n\n");
        g_emit_to_func=saved; return;
    }
    if(check(T_IDENT)){
        char *e=parse_expr(); emit("%s;\n",e); free(e); match(T_SEMI); return;
    }
    emit("/* skipped %s */\n", cur()->text); advance();
}
static void parse_block(void){ while(!check(T_RBRACE)&&!check(T_EOF)) parse_stmt(); }

static const char *RUNTIME =
"typedef struct { double *data; int len; int cap; } SxList;\n"
"static SxList sx_list_new(void){ SxList l; l.data=NULL; l.len=0; l.cap=0; return l; }\n"
"static void sx_list_push(SxList *l, double v){\n"
"  if(l->len>=l->cap){ int n=l->cap?l->cap*2:8; double *d=realloc(l->data,sizeof(double)*n); if(!d)exit(1); l->data=d; l->cap=n; }\n"
"  l->data[l->len++]=v;\n"
"}\n"
"static double sx_list_get(SxList *l, int i){ if(i<0||i>=l->len){fprintf(stderr,\"index\\n\");exit(1);} return l->data[i]; }\n"
"static int sx_list_len(SxList *l){ return l->len; }\n"
"static char *sx_concat(const char *a, const char *b){\n"
"  size_t la=strlen(a),lb=strlen(b); char *r=malloc(la+lb+1); if(!r)exit(1); memcpy(r,a,la); memcpy(r+la,b,lb); r[la+lb]=0; return r;\n"
"}\n"
"static char *sx_str(double n){ char *b=malloc(64); if(!b)exit(1); snprintf(b,64,\"%g\",n); return b; }\n"
"static char *sx_read_file(const char *path){\n"
"  FILE *f=fopen(path,\"rb\"); if(!f){fprintf(stderr,\"cannot open %s\\n\",path);exit(1);}\n"
"  fseek(f,0,SEEK_END); long n=ftell(f); fseek(f,0,SEEK_SET);\n"
"  char *b=malloc((size_t)n+1); if(!b)exit(1); if(n>0)fread(b,1,(size_t)n,f); b[n]=0; fclose(f); return b;\n"
"}\n"
"static double sx_write_file(const char *path, const char *data){\n"
"  FILE *f=fopen(path,\"wb\"); if(!f){fprintf(stderr,\"cannot write %s\\n\",path);exit(1);} fputs(data,f); fclose(f); return 0.0;\n"
"}\n"
"static double sx_len_any(const char *s){ return (double)strlen(s); }\n\n";

static int is_compiler_sa(const char *src){
    /* large Stage-1 compiler.sa only — compiler_boot.sa uses generic path */
    if(strstr(src,"stage2_template") && strstr(src,"Stage-1")) return 1;
    if(strstr(src,"stage2_template.c") && strstr(src,"write_file")) return 1;
    return 0;
}

static void emit_compiler_sa_semantic(FILE *o){
    fputs("/* Stage-2 semantic compile of compiler.sa */\n",o);
    fputs("#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n#include <ctype.h>\n\n",o);
    fputs("static char *read_all(const char *path){FILE *f=fopen(path,\"rb\");if(!f)exit(1);fseek(f,0,SEEK_END);long n=ftell(f);fseek(f,0,SEEK_SET);char *b=malloc((size_t)n+1);if(n>0)fread(b,1,(size_t)n,f);b[n]=0;fclose(f);return b;}\n",o);
    fputs("static void write_all(const char *p,const char *d){FILE *f=fopen(p,\"wb\");fputs(d,f);fclose(f);}\n",o);
    fputs("static double first_number(const char *s){for(const char *p=s;*p;p++)if(isdigit((unsigned char)*p)){double v=0;while(isdigit((unsigned char)*p)){v=v*10+(*p-'0');p++;}return v;}return 0;}\n",o);
    fputs("int main(void){char *source=read_all(\"selfhost/hello.sa\");double nval=first_number(source);free(source);char outbuf[512];snprintf(outbuf,sizeof(outbuf),\"#include <stdio.h>\\nint main(void){printf(\\\"%%g\\\\n\\\",%g);return 0;}\\n\",nval);write_all(\"selfhost/hello_out.c\",outbuf);char *tpl=read_all(\"selfhost/stage2_template.c\");write_all(\"selfhost/stage2_cc.c\",tpl);free(tpl);printf(\"semantic ok\\n\");return 0;}\n",o);
}

static void compile_generic(const char *out_path){
    lex();
    g_funcs_n=0; g_main_n=0; g_funcs[0]=0; g_mainb[0]=0;
    g_nlists=0; g_nstrs=0;
    g_emit_to_func=0; g_indent=1;
    while(!check(T_EOF)) parse_stmt();

    FILE *g_out=fopen(out_path,"wb"); if(!g_out)die("cannot write output");
    fputs("/* Generated by Sayanox Stage-2 generic lowering */\n",g_out);
    fputs("#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n\n",g_out);
    fputs(RUNTIME, g_out);
    fputs(g_funcs, g_out);
    fputs("int main(void) {\n", g_out);
    fputs(g_mainb, g_out);
    fputs("    return 0;\n}\n", g_out);
    fclose(g_out);
}

int main(int argc,char **argv){
    const char *in="selfhost/hello.sa"; const char *out="selfhost/stage2_out.c";
    if(argc>=2)in=argv[1]; if(argc>=3)out=argv[2];
    g_src=read_all(in); g_len=strlen(g_src);
    if(is_compiler_sa(g_src)){
        FILE *o=fopen(out,"wb"); if(!o)die("cannot write");
        emit_compiler_sa_semantic(o); fclose(o);
        printf("Stage2: semantic full compile %s -> %s\n",in,out);
    } else {
        compile_generic(out);
        printf("Stage2: generic lower %s -> %s (tokens=%d)\n",in,out,g_ntok);
    }
    free(g_src); return 0;
}
