/* Concurrent GC (pthread) for Stage-2 generated RUNTIME */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *readf(const char *p) {
  FILE *f = fopen(p, "rb");
  if (!f) return NULL;
  fseek(f, 0, SEEK_END);
  long n = ftell(f);
  fseek(f, 0, SEEK_SET);
  char *t = malloc((size_t)n + 1);
  if (!t) exit(1);
  fread(t, 1, (size_t)n, f);
  t[n] = 0;
  fclose(f);
  return t;
}

static int replace1(char **t, const char *old, const char *neu) {
  char *p = strstr(*t, old);
  if (!p) return 0;
  size_t lo = strlen(old), ln = strlen(neu), L = strlen(*t);
  size_t off = (size_t)(p - *t);
  char *n = malloc(L - lo + ln + 1);
  if (!n) exit(1);
  memcpy(n, *t, off);
  memcpy(n + off, neu, ln);
  memcpy(n + off + ln, p + lo, L - off - lo + 1);
  free(*t);
  *t = n;
  return 1;
}

int main(void) {
  char *t = readf("selfhost/stage2_template.c");
  if (!t) { fprintf(stderr, "inject_gc: cannot open template\n"); return 1; }
  if (strstr(t, "sx_gc_bg") && strstr(t, "sx_gc_start")) {
    puts("inject_gc: already present");
    free(t);
    return 0;
  }

  const char *old =
    "static char *sx_concat(const char *a, const char *b){ size_t la=strlen(a),lb=strlen(b); char *r=malloc(la+lb+1); if(!r)exit(1); memcpy(r,a,la); memcpy(r+la,b,lb); r[la+lb]=0; return r; }\\n"
    "static char *sx_str(double n){ char *b=malloc(64); if(!b)exit(1); snprintf(b,64,\\\"%g\\\",n); return b; }\\n";

  const char *neu =
    "/* concurrent GC */\\n"
    "#include <pthread.h>\\n"
    "#include <unistd.h>\\n"
    "#define SX_GC_MAX 8192\\n"
    "static char *sx_gc_reg[SX_GC_MAX]; static int sx_gc_rc[SX_GC_MAX]; static size_t sx_gc_sz[SX_GC_MAX];\\n"
    "static int sx_gc_n; static size_t sx_gc_bytes; static int sx_gc_cycles; static int sx_gc_running;\\n"
    "static pthread_mutex_t sx_gc_mu = PTHREAD_MUTEX_INITIALIZER; static pthread_t sx_gc_thr;\\n"
    "static void sx_gc_register(char *p, size_t n){ if(!p)return; pthread_mutex_lock(&sx_gc_mu); if(sx_gc_n<SX_GC_MAX){sx_gc_reg[sx_gc_n]=p;sx_gc_rc[sx_gc_n]=1;sx_gc_sz[sx_gc_n]=n;sx_gc_n++;sx_gc_bytes+=n;} pthread_mutex_unlock(&sx_gc_mu); }\\n"
    "static void sx_gc_release(char *p){ if(!p)return; pthread_mutex_lock(&sx_gc_mu); for(int i=0;i<sx_gc_n;i++)if(sx_gc_reg[i]==p){if(--sx_gc_rc[i]<=0){free(p);sx_gc_bytes-=sx_gc_sz[i];sx_gc_reg[i]=NULL;sx_gc_rc[i]=0;sx_gc_sz[i]=0;}break;} pthread_mutex_unlock(&sx_gc_mu); }\\n"
    "static void sx_gc_sweep_locked(void){ int w=0; for(int i=0;i<sx_gc_n;i++){ if(sx_gc_reg[i]&&sx_gc_rc[i]>0){sx_gc_reg[w]=sx_gc_reg[i];sx_gc_rc[w]=sx_gc_rc[i];sx_gc_sz[w]=sx_gc_sz[i];w++;} else if(sx_gc_reg[i]){free(sx_gc_reg[i]);} } sx_gc_n=w;sx_gc_cycles++; }\\n"
    "static void *sx_gc_bg(void *arg){ (void)arg; while(sx_gc_running){ usleep(50000); pthread_mutex_lock(&sx_gc_mu); sx_gc_sweep_locked(); pthread_mutex_unlock(&sx_gc_mu);} return NULL; }\\n"
    "static double sx_gc_start(void){ if(!sx_gc_running){sx_gc_running=1;pthread_create(&sx_gc_thr,NULL,sx_gc_bg,NULL);} return 1.0; }\\n"
    "static double sx_gc(void){ pthread_mutex_lock(&sx_gc_mu);sx_gc_sweep_locked();pthread_mutex_unlock(&sx_gc_mu); return (double)sx_gc_cycles; }\\n"
    "static double sx_gc_step(void){ pthread_mutex_lock(&sx_gc_mu);sx_gc_sweep_locked();pthread_mutex_unlock(&sx_gc_mu); return (double)sx_gc_n; }\\n"
    "static double sx_gc_info(void){ pthread_mutex_lock(&sx_gc_mu); double v=(double)sx_gc_bytes; pthread_mutex_unlock(&sx_gc_mu); return v; }\\n"
    "static char *sx_concat(const char *a, const char *b){ size_t la=strlen(a),lb=strlen(b); char *r=malloc(la+lb+1); if(!r)exit(1); memcpy(r,a,la); memcpy(r+la,b,lb); r[la+lb]=0; sx_gc_register(r,la+lb+1); return r; }\\n"
    "static char *sx_str(double n){ char *b=malloc(64); if(!b)exit(1); snprintf(b,64,\\\"%g\\\",n); sx_gc_register(b,64); return b; }\\n";

  if (!replace1(&t, old, neu)) {
    fprintf(stderr, "inject_gc: concat block not found\n");
    return 1;
  }

  if (!replace1(&t,
    "else if(!strcmp(buf,\"concat\"))snprintf(call,900,\"sx_concat(%s)\",args);",
    "else if(!strcmp(buf,\"concat\"))snprintf(call,900,\"sx_concat(%s)\",args);"
    "else if(!strcmp(buf,\"gc\"))snprintf(call,900,\"sx_gc()\",args);"
    "else if(!strcmp(buf,\"gc_step\"))snprintf(call,900,\"sx_gc_step()\",args);"
    "else if(!strcmp(buf,\"gc_info\"))snprintf(call,900,\"sx_gc_info()\",args);"
    "else if(!strcmp(buf,\"gc_start\"))snprintf(call,900,\"sx_gc_start()\",args);"
    "else if(!strcmp(buf,\"release\"))snprintf(call,900,\"(sx_gc_release(%s),0.0)\",args);"))
    fprintf(stderr, "inject_gc: warn builtins\n");

  replace1(&t,
    "emit(\"%s = %s;\\n\",name,e);}",
    "if(k==1)emit(\"sx_gc_release(%s); %s = %s;\\n\",name,name,e);else emit(\"%s = %s;\\n\",name,e);}");

  replace1(&t,
    "fputs(\"#include <stdio.h>\\n#include <stdlib.h>\\n#include <string.h>\\n#include <ctype.h>\\n\\n\",o);",
    "fputs(\"#include <stdio.h>\\n#include <stdlib.h>\\n#include <string.h>\\n#include <ctype.h>\\n#include <pthread.h>\\n#include <unistd.h>\\n\\n\",o);");

  FILE *o = fopen("selfhost/stage2_template.c", "wb");
  if (!o) return 1;
  fputs(t, o);
  fclose(o);
  free(t);
  puts("inject_gc: applied (pthread concurrent GC)");
  return 0;
}
