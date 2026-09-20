/* stage2_expand.inc - use/import module preprocessor (English) */
static char *dirname_of(const char *path){
    static char buf[1024];
    size_t n=strlen(path); if(n>=sizeof(buf)) n=sizeof(buf)-1;
    memcpy(buf,path,n); buf[n]=0;
    char *slash=strrchr(buf,'/');
    if(!slash){ strcpy(buf,"."); return buf; }
    *slash=0; if(!buf[0]) strcpy(buf,"/");
    return buf;
}
#define SX_IMPORT_DEPTH 64
static const char *sx_import_stack[SX_IMPORT_DEPTH];
static int sx_import_depth=0;
static int sx_import_active(const char *path){ for(int i=0;i<sx_import_depth;i++) if(!strcmp(sx_import_stack[i],path)) return 1; return 0; }
static char *expand_uses(const char *src, const char *infile){
    if(sx_import_depth>=SX_IMPORT_DEPTH){ fprintf(stderr,"stage2: %s: module import depth exceeds %d\n",infile,SX_IMPORT_DEPTH); exit(1); }
    if(sx_import_active(infile)){
        fprintf(stderr,"stage2: %s: cyclic module import detected\n",infile);
        fprintf(stderr,"stage2: import chain:");
        for(int i=0;i<sx_import_depth;i++) fprintf(stderr," %s ->",sx_import_stack[i]);
        fprintf(stderr," %s\n",infile); exit(1);
    }
    sx_import_stack[sx_import_depth++]=infile;
    char *dir=dirname_of(infile);
    size_t cap=strlen(src)+1; char *out=malloc(cap); if(!out)exit(1);
    size_t on=0; out[0]=0; const char *p=src;
    while(*p){
        const char *line=p; while(*p && *p!='\n') p++; size_t llen=(size_t)(p-line);
        const char *s=line; while(s<line+llen && (*s==' '||*s=='\t')) s++;
        int is_import=0; const char *q=NULL;
        if((size_t)(line+llen-s)>=4 && strncmp(s,"use ",4)==0){ is_import=1; q=s+4; }
        else if((size_t)(line+llen-s)>=7 && strncmp(s,"import ",7)==0){ is_import=1; q=s+7; }
        if(is_import){
            while(q<line+llen && (*q==' '||*q=='\t')) q++;
            if(q>=line+llen || *q!='"'){ fprintf(stderr,"stage2: %s: malformed module import; expected use/import \"path.sa\"\n",infile); exit(1); }
            q++; const char *qe=q; while(qe<line+llen && *qe!='"') qe++;
            if(qe>=line+llen){ fprintf(stderr,"stage2: %s: unterminated module path\n",infile); exit(1); }
            char rel[512]; size_t rn=(size_t)(qe-q); if(rn>=sizeof(rel)){ fprintf(stderr,"stage2: %s: module path is too long\n",infile); exit(1); }
            memcpy(rel,q,rn); rel[rn]=0;
            char full[1024]; if(rel[0]=='/') snprintf(full,sizeof(full),"%s",rel); else snprintf(full,sizeof(full),"%s/%s",dir,rel);
            char *inc=read_all(full); if(!inc){ fprintf(stderr,"stage2: %s: cannot import module \"%s\"\n",infile,full); exit(1); }
            char *nested=expand_uses(inc,full); free(inc); size_t nl=strlen(nested);
            if(on+nl+2>cap){ cap=on+nl+256; out=realloc(out,cap); if(!out)exit(1); }
            memcpy(out+on,nested,nl); on+=nl; out[on++]='\n'; out[on]=0; free(nested);
            if(*p=='\n') p++; continue;
        }
        if(on+llen+2>cap){ cap=on+llen+256; out=realloc(out,cap); if(!out)exit(1); }
        memcpy(out+on,line,llen); on+=llen; if(*p=='\n'){ out[on++]='\n'; p++; } out[on]=0;
    }
    sx_import_depth--; return out;
}
