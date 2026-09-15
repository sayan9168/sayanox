#!/usr/bin/env python3
"""Concurrent GC: atomic RC + background mark-sweep thread."""
from pathlib import Path
import re
import sys

path = Path("selfhost/stage2_template.c")
if not path.exists():
    print("patch_stage2_rc: no template")
    sys.exit(0)

src = path.read_text()

RUNTIME = r'''
#include <pthread.h>
#include <stdatomic.h>
typedef struct { double *data; int len; int cap; _Atomic int rc; } SxList;
typedef struct { unsigned magic; _Atomic int rc; size_t len; char data[]; } SxStr;
#define SX_STR_MAGIC 0x53585352u
static SxStr *sx_str_hdr(char *p){ return p ? (SxStr *)(p - (size_t)((char *)&((SxStr *)0)->data - (char *)0)) : 0; }
static int sx_str_is_heap(char *p){ SxStr *h=sx_str_hdr(p); return h && h->magic==SX_STR_MAGIC; }

static pthread_mutex_t sx_gc_mu = PTHREAD_MUTEX_INITIALIZER;
static char *sx_gc_strs[8192]; static int sx_gc_nstrs=0;
static SxList *sx_gc_lists[4096]; static int sx_gc_nlists=0;
static _Atomic int sx_gc_running=0;
static _Atomic int sx_gc_stop=0;
static pthread_t sx_gc_thread;
static int sx_gc_started=0;

static void sx_gc_track_str(char *p){
  if(!sx_str_is_heap(p)) return;
  pthread_mutex_lock(&sx_gc_mu);
  for(int i=0;i<sx_gc_nstrs;i++) if(sx_gc_strs[i]==p){ pthread_mutex_unlock(&sx_gc_mu); return; }
  if(sx_gc_nstrs<8192) sx_gc_strs[sx_gc_nstrs++]=p;
  pthread_mutex_unlock(&sx_gc_mu);
}
static void sx_gc_track_list(SxList *l){
  if(!l) return;
  pthread_mutex_lock(&sx_gc_mu);
  for(int i=0;i<sx_gc_nlists;i++) if(sx_gc_lists[i]==l){ pthread_mutex_unlock(&sx_gc_mu); return; }
  if(sx_gc_nlists<4096) sx_gc_lists[sx_gc_nlists++]=l;
  pthread_mutex_unlock(&sx_gc_mu);
}

static void sx_gc_sweep_unlocked(void){
  int w=0;
  for(int i=0;i<sx_gc_nstrs;i++){
    char *p=sx_gc_strs[i];
    if(!p) continue;
    if(!sx_str_is_heap(p)) continue;
    if(atomic_load(&sx_str_hdr(p)->rc)>0){ sx_gc_strs[w++]=p; continue; }
    free(sx_str_hdr(p));
  }
  sx_gc_nstrs=w;
  w=0;
  for(int i=0;i<sx_gc_nlists;i++){
    SxList *l=sx_gc_lists[i];
    if(!l) continue;
    if(atomic_load(&l->rc)>0){ sx_gc_lists[w++]=l; continue; }
    /* buffer already freed by drop when rc hit 0 */
  }
  sx_gc_nlists=w;
}

static void sx_gc(void){
  pthread_mutex_lock(&sx_gc_mu);
  sx_gc_sweep_unlocked();
  pthread_mutex_unlock(&sx_gc_mu);
}
static void sx_gc_sweep(void){ sx_gc(); }

static void *sx_gc_bg(void *arg){
  (void)arg;
  while(!atomic_load(&sx_gc_stop)){
    struct timespec ts; ts.tv_sec=0; ts.tv_nsec=50*1000*1000; /* 50ms */
    nanosleep(&ts,0);
    if(atomic_exchange(&sx_gc_running,1)) continue;
    sx_gc();
    atomic_store(&sx_gc_running,0);
  }
  return 0;
}

static void sx_gc_shutdown(void){
  atomic_store(&sx_gc_stop,1);
  if(sx_gc_started) pthread_join(sx_gc_thread,0);
  sx_gc();
}

static void sx_gc_start(void){
  if(sx_gc_started) return;
  sx_gc_started=1;
  atexit(sx_gc_shutdown);
  pthread_create(&sx_gc_thread,0,sx_gc_bg,0);
}

static char *sx_str_new_len(const char *s, size_t n){
  sx_gc_start();
  SxStr *h=(SxStr *)malloc(sizeof(SxStr)+n+1); if(!h)exit(1);
  h->magic=SX_STR_MAGIC; atomic_store(&h->rc,1); h->len=n;
  if(s && n) memcpy(h->data,s,n);
  h->data[n]=0; return h->data;
}
static char *sx_str_new(const char *s){ return sx_str_new_len(s, s?strlen(s):0); }
static char *sx_str_dup(const char *s){ char *p=sx_str_new(s?s:""); sx_gc_track_str(p); return p; }
static void sx_str_retain(char *p){ if(sx_str_is_heap(p)) atomic_fetch_add(&sx_str_hdr(p)->rc,1); }
static void sx_str_release(char *p){
  if(!sx_str_is_heap(p)) return;
  SxStr *h=sx_str_hdr(p);
  if(atomic_fetch_sub(&h->rc,1)==1){ h->magic=0; /* defer free to concurrent sweep */ }
}
static void sx_gc_track(char *p){ sx_gc_track_str(p); }

static SxList sx_list_new(void){ sx_gc_start(); SxList l; l.data=NULL; l.len=0; l.cap=0; atomic_store(&l.rc,1); return l; }
static SxList sx_list_clone(const SxList *src){
  SxList l=sx_list_new();
  if(!src||src->len<=0) return l;
  l.data=(double*)malloc(sizeof(double)*(size_t)src->len); if(!l.data)exit(1);
  memcpy(l.data,src->data,sizeof(double)*(size_t)src->len);
  l.len=src->len; l.cap=src->len; atomic_store(&l.rc,1); return l;
}
static void sx_list_retain(SxList *l){ if(l) atomic_fetch_add(&l->rc,1); }
static void sx_list_drop(SxList *l){
  if(!l) return;
  if(atomic_fetch_sub(&l->rc,1)==1){
    free(l->data); l->data=NULL; l->len=0; l->cap=0;
  }
}
static void sx_list_push(SxList *l, double v){
  if(l->len>=l->cap){ int n=l->cap?l->cap*2:8; double *d=(double*)realloc(l->data,sizeof(double)*(size_t)n); if(!d)exit(1); l->data=d; l->cap=n; }
  l->data[l->len++]=v;
}
static double sx_list_get(SxList *l, int i){ if(i<0||i>=l->len){fprintf(stderr,"index\n");exit(1);} return l->data[i]; }
static int sx_list_len(SxList *l){ return l->len; }
static char *sx_concat(const char *a, const char *b){
  size_t la=strlen(a),lb=strlen(b);
  char *r=sx_str_new_len(0, la+lb);
  memcpy(r,a,la); memcpy(r+la,b,lb); r[la+lb]=0;
  sx_gc_track_str(r); return r;
}
static char *sx_str(double n){ char tmp[64]; snprintf(tmp,64,"%g",n); char *r=sx_str_new(tmp); sx_gc_track_str(r); return r; }
static char *sx_read_file(const char *path){
  FILE *f=fopen(path,"rb"); if(!f){fprintf(stderr,"cannot open %s\n",path);exit(1);}
  fseek(f,0,SEEK_END); long n=ftell(f); fseek(f,0,SEEK_SET);
  char *r=sx_str_new_len(0,(size_t)n); if(n>0)fread(r,1,(size_t)n,f); r[n]=0; fclose(f); sx_gc_track_str(r); return r;
}
static double sx_write_file(const char *path, const char *data){ FILE *f=fopen(path,"wb"); if(!f){fprintf(stderr,"cannot write %s\n",path);exit(1);} fputs(data,f); fclose(f); return 0.0; }
static double sx_len_any(const char *s){ return (double)strlen(s); }
static double sx_contains(const char *a,const char *b){ return strstr(a,b)?1.0:0.0; }
static double sx_starts_with(const char *a,const char *b){ size_t n=strlen(b); return strncmp(a,b,n)==0?1.0:0.0; }
static double sx_ends_with(const char *a,const char *b){ size_t la=strlen(a),lb=strlen(b); if(lb>la)return 0.0; return strcmp(a+la-lb,b)==0?1.0:0.0; }
static char *sx_upper(const char *s){ size_t n=strlen(s); char *r=sx_str_new_len(0,n); for(size_t i=0;i<n;i++) r[i]=(char)toupper((unsigned char)s[i]); r[n]=0; sx_gc_track_str(r); return r; }
static char *sx_lower(const char *s){ size_t n=strlen(s); char *r=sx_str_new_len(0,n); for(size_t i=0;i<n;i++) r[i]=(char)tolower((unsigned char)s[i]); r[n]=0; sx_gc_track_str(r); return r; }
static char *sx_trim(const char *s){ while(*s&&isspace((unsigned char)*s))s++; size_t n=strlen(s); while(n>0&&isspace((unsigned char)s[n-1]))n--; char *r=sx_str_new_len(s,n); sx_gc_track_str(r); return r; }
'''

m = re.search(r'static const char \*RUNTIME="(.*?)";\n', src, re.S)
if not m:
    print("patch_stage2_rc: RUNTIME not found — skip")
    sys.exit(0)

def to_c_string(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")

src = src[: m.start(1)] + to_c_string(RUNTIME.strip() + "\n") + src[m.end(1) :]

# Generated programs need pthread + stdatomic headers and need nanosleep (time.h)
old_inc = 'fputs("#include <stdio.h>\\n#include <stdlib.h>\\n#include <string.h>\\n#include <ctype.h>\\n\\n",o);'
new_inc = 'fputs("#include <stdio.h>\\n#include <stdlib.h>\\n#include <string.h>\\n#include <ctype.h>\\n#include <pthread.h>\\n#include <stdatomic.h>\\n#include <time.h>\\n\\n",o);'
if old_inc in src:
    src = src.replace(old_inc, new_inc, 1)
else:
    # try unescaped form in source file
    old2 = 'fputs("#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n#include <ctype.h>\n\n",o);'
    new2 = 'fputs("#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n#include <ctype.h>\n#include <pthread.h>\n#include <stdatomic.h>\n#include <time.h>\n\n",o);'
    if old2 in src:
        src = src.replace(old2, new2, 1)

path.write_text(src)
print("Patched RUNTIME: concurrent GC (bg thread + atomic RC)")
