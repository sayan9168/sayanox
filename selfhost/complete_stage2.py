#!/usr/bin/env python3
"""Complete Stage-2 template with use expansion and lexer runtime support."""
from pathlib import Path

p = Path("selfhost/stage2_template.c")
src = p.read_text()

header = """/* Sayanox Stage-2 - generic .sa to C compiler (self-host path).
 * Features: show/hold/when/while/make/struct, lists, strings, modulo,
 * bare assign, type-safe hold, stdlib, use expansion, Unicode lexer helpers.
 * All messages in English.
 */
"""
if "#include" in src:
    src = header + src[src.find("#include") :]

src = src.replace(
    'snprintf(n,900,"((double)((long)(%s)%(long)(%s)))",left,right);',
    'snprintf(n,900,"((double)((long)(%s)%%(long)(%s)))",left,right);',
)

src = src.replace(
    'strstr(e,\\"sx_trim\\")?1:0;',
    'strstr(e,\\"sx_trim\\")||strstr(e,\\"sx_char_at\\")||strstr(e,\\"sx_char_from_code\\")?1:0;',
)

# Emit extra runtime functions as ordinary generated C instead of embedding them
# inside the legacy RUNTIME string. This keeps the generated Stage-2 C valid.
extra_runtime = r'''fputs("static size_t sx_utf8_next(const unsigned char *p){ if(p[0]<0x80)return 1; if((p[0]&0xE0)==0xC0)return 2; if((p[0]&0xF0)==0xE0)return 3; if((p[0]&0xF8)==0xF0)return 4; return 1; }\nstatic size_t sx_string_len(const char *s){ size_t i=0,n=0; while(s[i]){ i+=sx_utf8_next((const unsigned char*)s+i); n++; } return n; }\nstatic unsigned int sx_char_code(const char *s,int index){ size_t i=0; for(int n=0;n<index && s[i];n++) i+=sx_utf8_next((const unsigned char*)s+i); if(!s[i])return 0; const unsigned char *p=(const unsigned char*)s+i; if(p[0]<0x80)return p[0]; if((p[0]&0xE0)==0xC0)return ((p[0]&0x1F)<<6)|(p[1]&0x3F); if((p[0]&0xF0)==0xE0)return ((p[0]&0x0F)<<12)|((p[1]&0x3F)<<6)|(p[2]&0x3F); return ((p[0]&0x07)<<18)|((p[1]&0x3F)<<12)|((p[2]&0x3F)<<6)|(p[3]&0x3F); }\nstatic char *sx_char_at(const char *s,int index){ size_t i=0; for(int n=0;n<index && s[i];n++) i+=sx_utf8_next((const unsigned char*)s+i); if(!s[i]){ char *z=malloc(1); z[0]=0; return z; } size_t w=sx_utf8_next((const unsigned char*)s+i); char *r=malloc(w+1); if(!r)exit(1); memcpy(r,s+i,w); r[w]=0; return r; }\nstatic char *sx_char_from_code(unsigned int code){ int w=code<0x80?1:code<0x800?2:code<0x10000?3:4; char *r=malloc((size_t)w+1); if(!r)exit(1); if(w==1)r[0]=(char)code; else if(w==2){r[0]=(char)(0xC0|(code>>6));r[1]=(char)(0x80|(code&0x3F));} else if(w==3){r[0]=(char)(0xE0|(code>>12));r[1]=(char)(0x80|((code>>6)&0x3F));r[2]=(char)(0x80|(code&0x3F));} else {r[0]=(char)(0xF0|(code>>18));r[1]=(char)(0x80|((code>>12)&0x3F));r[2]=(char)(0x80|((code>>6)&0x3F));r[3]=(char)(0x80|(code&0x3F));} r[w]=0; return r; }\n",o);
'''
if 'sx_string_len' not in src:
    src = src.replace('fputs(RUNTIME,o);fputs(g_types,o);', 'fputs(RUNTIME,o);' + extra_runtime + 'fputs(g_types,o);', 1)

expand = r"""
static char *dirname_of(const char *path){
    static char buf[1024];
    size_t n=strlen(path); if(n>=sizeof(buf)) n=sizeof(buf)-1;
    memcpy(buf,path,n); buf[n]=0;
    char *slash=strrchr(buf,'/');
    if(!slash){ strcpy(buf,"."); return buf; }
    *slash=0; if(!buf[0]) strcpy(buf,"/");
    return buf;
}
static char *expand_uses(const char *src, const char *infile){
    char *dir=dirname_of(infile);
    size_t cap=strlen(src)+1;
    char *out=malloc(cap); if(!out)exit(1);
    size_t on=0; out[0]=0;
    const char *p=src;
    while(*p){
        const char *line=p;
        while(*p && *p!='\n') p++;
        size_t llen=(size_t)(p-line);
        const char *s=line;
        while(s<line+llen && (*s==' '||*s=='\t')) s++;
        if((size_t)(line+llen-s)>=4 && strncmp(s,"use ",4)==0){
            const char *q=s+4;
            while(q<line+llen && (*q==' '||*q=='\t')) q++;
            if(q<line+llen && *q=='"'){
                q++;
                const char *qe=q;
                while(qe<line+llen && *qe!='"') qe++;
                if(qe>q && qe<line+llen && *qe=='"'){
                    char rel[512]; size_t rn=(size_t)(qe-q); if(rn>sizeof(rel)-1) rn=sizeof(rel)-1;
                    memcpy(rel,q,rn); rel[rn]=0;
                    char full[1024];
                    snprintf(full,sizeof(full),"%s/%s",dir,rel);
                    char *inc=read_all(full);
                    char *nested=expand_uses(inc, full);
                    free(inc);
                    size_t nl=strlen(nested);
                    if(on+nl+2>cap){ cap=on+nl+256; out=realloc(out,cap); if(!out)exit(1); }
                    memcpy(out+on,nested,nl); on+=nl; out[on++]='\n'; out[on]=0;
                    free(nested);
                    if(*p=='\n') p++;
                    continue;
                }
            }
        }
        if(on+llen+2>cap){ cap=on+llen+256; out=realloc(out,cap); if(!out)exit(1); }
        memcpy(out+on,line,llen); on+=llen;
        if(*p=='\n'){ out[on++]='\n'; p++; }
        out[on]=0;
    }
    return out;
}
"""
if "expand_uses" not in src:
    src = src.replace("static void compile_generic", expand + "\nstatic void compile_generic", 1)

old = "g_path=in;g_src=read_all(in);g_len=strlen(g_src);"
new = "g_path=in;{char *raw=read_all(in);g_src=expand_uses(raw,in);free(raw);}g_len=strlen(g_src);"
if old in src:
    src = src.replace(old, new)

p.write_text(src)
print(f"Wrote complete Stage-2 ({len(src)} bytes)")
