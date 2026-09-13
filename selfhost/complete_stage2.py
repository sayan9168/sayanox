#!/usr/bin/env python3
"""Complete Stage-2 template: English header, modulo fix, use expansion."""
from pathlib import Path

p = Path("selfhost/stage2_template.c")
src = p.read_text()

header = """/* Sayanox Stage-2 - generic .sa to C compiler (self-host path).
 * Features: show/hold/when/while/make/struct, lists, strings, modulo,
 * bare assign, type-safe hold, stdlib, use "file.sa" expansion.
 * All messages in English.
 */
"""
if "#include" in src:
    src = header + src[src.find("#include") :]

src = src.replace(
    'snprintf(n,900,"((double)((long)(%s)%(long)(%s)))",left,right);',
    'snprintf(n,900,"((double)((long)(%s)%%(long)(%s)))",left,right);',
)

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
    src = src.replace(
        "static void compile_generic", expand + "\nstatic void compile_generic", 1
    )

old = "g_path=in;g_src=read_all(in);g_len=strlen(g_src);"
new = "g_path=in;{char *raw=read_all(in);g_src=expand_uses(raw,in);free(raw);}g_len=strlen(g_src);"
if old in src:
    src = src.replace(old, new)

p.write_text(src)
print(f"Wrote complete Stage-2 ({len(src)} bytes)")
