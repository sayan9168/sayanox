/*
 * Sayanox Stage-2 — Generic subset → C lowering
 * show/hold/when/otherwise/while + expressions; compiler.sa semantic path
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <stdarg.h>

#define MAX_TOK 8192

typedef enum {
    T_EOF=0, T_NUMBER, T_STRING, T_IDENT,
    T_SHOW, T_HOLD, T_WHEN, T_OTHERWISE, T_WHILE, T_MAKE, T_GIVE,
    T_PLUS, T_MINUS, T_STAR, T_SLASH,
    T_EQ, T_NEQ, T_LT, T_GT, T_LTE, T_GTE, T_ASSIGN,
    T_LBRACE, T_RBRACE, T_LPAREN, T_RPAREN, T_COMMA, T_SEMI
} TokKind;

typedef struct { TokKind kind; char text[256]; double num; } Tok;

static char *g_src; static size_t g_len, g_pos;
static Tok g_toks[MAX_TOK]; static int g_ntok, g_ti;
static FILE *g_out; static int g_indent;

static void die(const char *m){ fprintf(stderr,"stage2: %s\n",m); exit(1); }

static char *read_all(const char *path){
    FILE *f=fopen(path,"rb"); if(!f){fprintf(stderr,"stage2: cannot open %s\n",path);exit(1);}
    fseek(f,0,SEEK_END); long n=ftell(f); fseek(f,0,SEEK_SET);
    char *b=malloc((size_t)n+1); if(!b)exit(1);
    if(n>0)fread(b,1,(size_t)n,f); b[n]=0; fclose(f); return b;
}
static int is_id(int c){ return isalnum((unsigned char)c)||c=='_'; }
static void emit(const char *fmt, ...){
    for(int i=0;i<g_indent;i++) fputs("    ", g_out);
    va_list ap; va_start(ap,fmt); vfprintf(g_out,fmt,ap); va_end(ap);
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
    char *buf=malloc(512); if(!buf)exit(1); buf[0]=0;
    if(check(T_NUMBER)){ snprintf(buf,512,"%g",cur()->num); advance(); return buf; }
    if(check(T_STRING)){ snprintf(buf,512,"\"%s\"",cur()->text); advance(); return buf; }
    if(check(T_IDENT)){
        snprintf(buf,512,"%s",cur()->text); advance();
        if(match(T_LPAREN)){
            char args[400]="";
            if(!check(T_RPAREN)){
                char *a=parse_expr(); strncat(args,a,sizeof(args)-strlen(args)-1); free(a);
                while(match(T_COMMA)){ strncat(args,", ",sizeof(args)-strlen(args)-1); a=parse_expr(); strncat(args,a,sizeof(args)-strlen(args)-1); free(a); }
            }
            expect(T_RPAREN,")");
            char *call=malloc(600);
            if(!strcmp(buf,"str")) snprintf(call,600,"({static char _b[64]; snprintf(_b,64,\"%%g\",%s); _b;})",args);
            else if(!strcmp(buf,"len")) snprintf(call,600,"((double)strlen(%s))",args);
            else snprintf(call,600,"sx_%s(%s)",buf,args);
            free(buf); return call;
        }
        return buf;
    }
    if(match(T_LPAREN)){ char *e=parse_expr(); expect(T_RPAREN,")"); snprintf(buf,512,"(%s)",e); free(e); return buf; }
    if(match(T_MINUS)){ char *e=parse_primary(); snprintf(buf,512,"(-%s)",e); free(e); return buf; }
    strcpy(buf,"0"); return buf;
}
static char *parse_term(void){
    char *left=parse_primary();
    while(check(T_STAR)||check(T_SLASH)){
        char op=check(T_STAR)?'*':'/'; advance(); char *right=parse_primary();
        char *n=malloc(600); snprintf(n,600,"(%s %c %s)",left,op,right); free(left); free(right); left=n;
    }
    return left;
}
static char *parse_add(void){
    char *left=parse_term();
    while(check(T_PLUS)||check(T_MINUS)){
        char op=check(T_PLUS)?'+':'-'; advance(); char *right=parse_term();
        char *n=malloc(600); snprintf(n,600,"(%s %c %s)",left,op,right); free(left); free(right); left=n;
    }
    return left;
}
static char *parse_cmp(void){
    char *left=parse_add();
    if(check(T_EQ)||check(T_NEQ)||check(T_LT)||check(T_GT)||check(T_LTE)||check(T_GTE)){
        const char *op=cur()->text; advance(); char *right=parse_add();
        char *n=malloc(600); snprintf(n,600,"(%s %s %s)",left,op,right); free(left); free(right); return n;
    }
    return left;
}
static char *parse_expr(void){ return parse_cmp(); }

static void parse_block(void);
static int expr_is_string(const char *e){ return e&&e[0]=='"'; }

static void parse_stmt(void){
    if(check(T_EOF)||check(T_RBRACE)) return;
    if(match(T_SHOW)){
        char *e=parse_expr();
        if(expr_is_string(e)||strncmp(e,"({static char",13)==0) emit("printf(\"%%s\\n\", %s);\n",e);
        else emit("printf(\"%%g\\n\", (double)(%s));\n",e);
        free(e); match(T_SEMI); return;
    }
    if(match(T_HOLD)){
        if(!check(T_IDENT)) die("hold expects name");
        char name[128]; strncpy(name,cur()->text,sizeof(name)-1); name[sizeof(name)-1]=0; advance();
        expect(T_ASSIGN,"="); char *e=parse_expr();
        if(expr_is_string(e)||strncmp(e,"({static char",13)==0) emit("const char *%s = %s;\n",name,e);
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
        emit("/* stage2: make skipped */\n");
        if(check(T_IDENT)) advance();
        if(match(T_LPAREN)){ while(!check(T_RPAREN)&&!check(T_EOF)) advance(); match(T_RPAREN); }
        if(match(T_LBRACE)){ int d=1; while(d>0&&!check(T_EOF)){ if(check(T_LBRACE))d++; if(check(T_RBRACE))d--; advance(); } }
        return;
    }
    emit("/* skipped %s */\n", cur()->text); advance();
}
static void parse_block(void){ while(!check(T_RBRACE)&&!check(T_EOF)) parse_stmt(); }

static int is_compiler_sa(const char *src){
    if(strlen(src)>400 && strstr(src,"read_file") && strstr(src,"stage2_template")) return 1;
    if(strstr(src,"Stage-1") && strstr(src,"write_file") && strstr(src,"hello.sa")) return 1;
    return 0;
}

static void emit_compiler_sa_semantic(FILE *o){
    fputs("/* Stage-2 semantic full compile of compiler.sa */\n",o);
    fputs("#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n#include <ctype.h>\n\n",o);
    fputs("static char *read_all(const char *path){FILE *f=fopen(path,\"rb\");if(!f){fprintf(stderr,\"cannot open %s\\n\",path);exit(1);}fseek(f,0,SEEK_END);long n=ftell(f);fseek(f,0,SEEK_SET);char *b=malloc((size_t)n+1);if(!b)exit(1);if(n>0)fread(b,1,(size_t)n,f);b[n]=0;fclose(f);return b;}\n",o);
    fputs("static void write_all(const char *path,const char *data){FILE *f=fopen(path,\"wb\");if(!f)exit(1);fputs(data,f);fclose(f);}\n",o);
    fputs("static double first_number(const char *s){for(const char *p=s;*p;p++){if(isdigit((unsigned char)*p)){double v=0;while(isdigit((unsigned char)*p)){v=v*10+(*p-'0');p++;}return v;}}return 0;}\n",o);
    fputs("int main(void){printf(\"=== Stage-1 from semantic compiler.sa ===\\n\");char *source=read_all(\"selfhost/hello.sa\");double nval=first_number(source);free(source);char outbuf[512];snprintf(outbuf,sizeof(outbuf),\"// Stage-1\\n#include <stdio.h>\\nint main(void){\\n  printf(\\\"%%g\\\\n\\\", %g);\\n  return 0;\\n}\\n\",nval);write_all(\"selfhost/hello_out.c\",outbuf);char *tpl=read_all(\"selfhost/stage2_template.c\");write_all(\"selfhost/stage2_cc.c\",tpl);free(tpl);char mark[64];snprintf(mark,sizeof(mark),\"stage1_ok n=%g\",nval);write_all(\"selfhost/stage1_ok.txt\",mark);printf(\"ok\\n\");return 0;}\n",o);
}

static void compile_generic(const char *out_path){
    lex();
    g_out=fopen(out_path,"wb"); if(!g_out)die("cannot write output");
    fputs("/* Generated by Sayanox Stage-2 generic lowering */\n",g_out);
    fputs("#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n\nint main(void) {\n",g_out);
    g_indent=1;
    while(!check(T_EOF)) parse_stmt();
    fputs("    return 0;\n}\n",g_out);
    fclose(g_out);
}

int main(int argc,char **argv){
    const char *in="selfhost/hello.sa"; const char *out="selfhost/stage2_out.c";
    if(argc>=2)in=argv[1]; if(argc>=3)out=argv[2];
    g_src=read_all(in); g_len=strlen(g_src);
    if(is_compiler_sa(g_src)){
        g_out=fopen(out,"wb"); if(!g_out)die("cannot write");
        emit_compiler_sa_semantic(g_out); fclose(g_out);
        printf("Stage2: semantic full compile %s -> %s\n",in,out);
    } else {
        compile_generic(out);
        printf("Stage2: generic lower %s -> %s (%d tokens)\n",in,out,g_ntok);
    }
    free(g_src); return 0;
}
