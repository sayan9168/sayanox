/* Tool-only POSIX directory bridge. Included after gen2's runtime definitions.
 * No language builtin, shell process, network, or external index is involved.
 * Result: alternating percent-encoded file URI and absolute pathname lines.
 */
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>
#include <limits.h>
#ifndef PATH_MAX
#define PATH_MAX 4096
#endif
#define SX_WS_MANIFEST (2u * 1024u * 1024u)
#define SX_WS_FILES 128
#define SX_WS_ENTRIES 4096
#define SX_WS_BYTES (4u * 1024u * 1024u)
#define SX_WS_FILE_BYTES (256u * 1024u)

typedef struct {
    char *data;
    size_t used, bytes;
    unsigned files, entries;
} sx_ws_scan;
static int sx_ws_hex(unsigned char c) {
    if(c >= '0' && c <= '9') return c-'0';
    if(c >= 'a' && c <= 'f') return c-'a'+10;
    if(c >= 'A' && c <= 'F') return c-'A'+10;
    return -1;
}
static int sx_ws_root(const char *uri, char *out) {
    const char *p;
    if(!strncmp(uri,"file:///",8)) p=uri+7;
    else if(!strncmp(uri,"file://localhost/",17)) p=uri+16;
    else return 0;
    size_t n=0;
    while(*p) {
        unsigned char c=(unsigned char)*p++;
        if(c=='%') {
            if(!p[0] || !p[1]) return 0;
            int a=sx_ws_hex((unsigned char)p[0]), b=sx_ws_hex((unsigned char)p[1]);
            if(a<0 || b<0) return 0;
            c=(unsigned char)(a*16+b); p+=2;
        }
        if(!c || c=='\n' || c=='\r' || n+1>=PATH_MAX) return 0;
        out[n++]=(char)c;
    }
    out[n]=0;
    return n>0 && out[0]=='/';
}
static int sx_ws_cmp(const void *a,const void *b) {
    return strcmp(*(char * const *)a,*(char * const *)b);
}
static int sx_ws_skip(const char *n) {
    return n[0]=='.' || !strcmp(n,"node_modules") || !strcmp(n,"build") ||
           !strcmp(n,"dist") || !strcmp(n,"target") || !strcmp(n,"vendor");
}
static void sx_ws_file(sx_ws_scan *s,const char *path,size_t bytes) {
    static const char hex[]="0123456789ABCDEF";
    size_t len=strlen(path), need=7+3*len+1+len+1;
    if(s->files>=SX_WS_FILES || bytes>SX_WS_FILE_BYTES ||
       s->bytes+bytes>SX_WS_BYTES || s->used+need>=SX_WS_MANIFEST) return;
    char *p=s->data+s->used;
    memcpy(p,"file://",7); p+=7;
    for(const unsigned char *q=(const unsigned char*)path; *q; q++) {
        unsigned char c=*q;
        if((c>='a'&&c<='z') || (c>='A'&&c<='Z') || (c>='0'&&c<='9') ||
           c=='/' || c=='-' || c=='_' || c=='.' || c=='~') *p++=(char)c;
        else { *p++='%'; *p++=hex[c>>4]; *p++=hex[c&15]; }
    }
    *p++='\n'; memcpy(p,path,len); p+=len; *p++='\n';
    s->used=(size_t)(p-s->data); s->files++; s->bytes+=bytes;
}
static void sx_ws_walk(sx_ws_scan *s,const char *dir,unsigned depth) {
    if(depth>16 || s->entries>=SX_WS_ENTRIES || s->files>=SX_WS_FILES) return;
    DIR *d=opendir(dir);
    if(!d) return;
    char **names=calloc(SX_WS_ENTRIES,sizeof *names);
    if(!names) { closedir(d); return; }
    size_t n=0;
    struct dirent *ent;
    while((ent=readdir(d)) && n<SX_WS_ENTRIES) {
        if(sx_ws_skip(ent->d_name)) continue;
        names[n]=strdup(ent->d_name);
        if(!names[n]) break;
        n++;
    }
    closedir(d);
    qsort(names,n,sizeof *names,sx_ws_cmp);
    for(size_t i=0;i<n;i++) {
        if(s->entries>=SX_WS_ENTRIES || s->files>=SX_WS_FILES) break;
        s->entries++;
        char path[PATH_MAX];
        int k=snprintf(path,sizeof path,"%s/%s",dir,names[i]);
        if(k<0 || (size_t)k>=sizeof path || strchr(path,'\n') || strchr(path,'\r')) continue;
        struct stat st;
        if(lstat(path,&st)) continue;
        if(S_ISDIR(st.st_mode)) sx_ws_walk(s,path,depth+1);
        else if(S_ISREG(st.st_mode)) {
            size_t len=strlen(path);
            if(len>=3 && !strcmp(path+len-3,".sa") && st.st_size>=0)
                sx_ws_file(s,path,(size_t)st.st_size);
        }
    }
    for(size_t i=0;i<n;i++) free(names[i]);
    free(names);
}
static char *sx_lsp_workspace_manifest(const char *root) {
    char decoded[PATH_MAX], canonical[PATH_MAX];
    struct stat st;
    if(!sx_ws_root(root,decoded) || !realpath(decoded,canonical) ||
       stat(canonical,&st) || !S_ISDIR(st.st_mode)) return "";
    sx_ws_scan scan={0};
    scan.data=malloc(SX_WS_MANIFEST);
    if(!scan.data) return "";
    sx_ws_walk(&scan,canonical,0);
    char *result=(char*)sx_gc_alloc(0,scan.used+1);
    memcpy(result,scan.data,scan.used); result[scan.used]=0;
    free(scan.data);
    return result;
}
