/* stage2_expand.inc - use "file.sa" preprocessor (English) */
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
