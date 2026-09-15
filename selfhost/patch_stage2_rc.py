#!/usr/bin/env python3
"""Arena strings + ref-counted lists in Stage-2 RUNTIME."""
from pathlib import Path
import re
import sys

path = Path("selfhost/stage2_template.c")
if not path.exists():
    print("patch_stage2_rc: no template")
    sys.exit(0)

src = path.read_text()

ARENA = r'''
typedef struct { double *data; int len; int cap; int rc; } SxList;
/* Region GC for strings: bump arena freed at process exit. */
static unsigned char *sx_heap=0; static size_t sx_heap_n=0, sx_heap_cap=0;
static void sx_heap_free(void){ free(sx_heap); sx_heap=0; sx_heap_n=0; sx_heap_cap=0; }
static void *sx_alloc(size_t n){
  if(!sx_heap){ atexit(sx_heap_free); sx_heap_cap=1<<20; sx_heap=(unsigned char*)malloc(sx_heap_cap); if(!sx_heap)exit(1); }
  n=(n+7)&~(size_t)7;
  if(sx_heap_n+n>sx_heap_cap){ size_t nc=sx_heap_cap*2; while(sx_heap_n+n>nc) nc*=2; unsigned char *p=(unsigned char*)realloc(sx_heap,nc); if(!p)exit(1); sx_heap=p; sx_heap_cap=nc; }
  void *r=sx_heap+sx_heap_n; sx_heap_n+=n; return r;
}
static SxList sx_list_new(void){ SxList l; l.data=NULL; l.len=0; l.cap=0; l.rc=1; return l; }
static void sx_list_retain(SxList *l){ if(l) l->rc++; }
static void sx_list_drop(SxList *l){
  if(!l) return;
  if(l->rc>1){ l->rc--; return; }
  free(l->data); l->data=NULL; l->len=0; l->cap=0; l->rc=0;
}
static void sx_list_push(SxList *l, double v){
  if(l->len>=l->cap){ int n=l->cap?l->cap*2:8; double *d=(double*)realloc(l->data,sizeof(double)*(size_t)n); if(!d)exit(1); l->data=d; l->cap=n; }
  l->data[l->len++]=v;
}
static double sx_list_get(SxList *l, int i){ if(i<0||i>=l->len){fprintf(stderr,"index\n");exit(1);} return l->data[i]; }
static int sx_list_len(SxList *l){ return l->len; }
static char *sx_concat(const char *a, const char *b){ size_t la=strlen(a),lb=strlen(b); char *r=(char*)sx_alloc(la+lb+1); memcpy(r,a,la); memcpy(r+la,b,lb); r[la+lb]=0; return r; }
static char *sx_str(double n){ char *b=(char*)sx_alloc(64); snprintf(b,64,"%g",n); return b; }
static char *sx_read_file(const char *path){ FILE *f=fopen(path,"rb"); if(!f){fprintf(stderr,"cannot open %s\n",path);exit(1);} fseek(f,0,SEEK_END); long n=ftell(f); fseek(f,0,SEEK_SET); char *b=(char*)sx_alloc((size_t)n+1); if(n>0)fread(b,1,(size_t)n,f); b[n]=0; fclose(f); return b; }
static double sx_write_file(const char *path, const char *data){ FILE *f=fopen(path,"wb"); if(!f){fprintf(stderr,"cannot write %s\n",path);exit(1);} fputs(data,f); fclose(f); return 0.0; }
static double sx_len_any(const char *s){ return (double)strlen(s); }
static double sx_contains(const char *a,const char *b){ return strstr(a,b)?1.0:0.0; }
static double sx_starts_with(const char *a,const char *b){ size_t n=strlen(b); return strncmp(a,b,n)==0?1.0:0.0; }
static double sx_ends_with(const char *a,const char *b){ size_t la=strlen(a),lb=strlen(b); if(lb>la)return 0.0; return strcmp(a+la-lb,b)==0?1.0:0.0; }
static char *sx_upper(const char *s){ size_t n=strlen(s); char *r=(char*)sx_alloc(n+1); for(size_t i=0;i<n;i++) r[i]=(char)toupper((unsigned char)s[i]); r[n]=0; return r; }
static char *sx_lower(const char *s){ size_t n=strlen(s); char *r=(char*)sx_alloc(n+1); for(size_t i=0;i<n;i++) r[i]=(char)tolower((unsigned char)s[i]); r[n]=0; return r; }
static char *sx_trim(const char *s){ while(*s&&isspace((unsigned char)*s))s++; size_t n=strlen(s); while(n>0&&isspace((unsigned char)s[n-1]))n--; char *r=(char*)sx_alloc(n+1); memcpy(r,s,n); r[n]=0; return r; }
'''

m = re.search(r'static const char \*RUNTIME="(.*?)";\n', src, re.S)
if not m:
    print("patch_stage2_rc: RUNTIME not found — skip")
    sys.exit(0)

def to_c_string(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")

new_runtime = to_c_string(ARENA.strip() + "\n")
src = src[: m.start(1)] + new_runtime + src[m.end(1) :]
path.write_text(src)
print("Patched Stage-2 RUNTIME: arena strings + list RC")
