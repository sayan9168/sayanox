/* Reference-counted runtime patch for generated Stage-2 C programs.
 * This implementation is single-threaded. It deliberately does not start
 * background threads or claim concurrent collection.
 */
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
  if (fread(t, 1, (size_t)n, f) != (size_t)n) { fclose(f); free(t); return NULL; }
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
  if (!t) {
    fprintf(stderr, "inject_gc: cannot open selfhost/stage2_template.c\n");
    return 1;
  }

  if (strstr(t, "sx_rc_retain") && strstr(t, "sx_rc_release")) {
    puts("inject_gc: reference-counted runtime already present");
    free(t);
    return 0;
  }

  const char *old =
    "static char *sx_concat(const char *a, const char *b){ size_t la=strlen(a),lb=strlen(b); char *r=malloc(la+lb+1); if(!r)exit(1); memcpy(r,a,la); memcpy(r+la,b,lb); r[la+lb]=0; return r; }\\n"
    "static char *sx_str(double n){ char *b=malloc(64); if(!b)exit(1); snprintf(b,64,\\\"%g\\\",n); return b; }\\n";

  const char *neu =
    "/* Sayanox reference-counted string runtime. Single-threaded. */\\n"
    "typedef struct SxRcStr { size_t refs; size_t size; char data[]; } SxRcStr;\\n"
    "static SxRcStr *sx_rc_from(const char *p){ if(!p)return NULL; return (SxRcStr*)((char*)p-sizeof(SxRcStr)); }\\n"
    "static char *sx_rc_new(size_t n){ SxRcStr *h=(SxRcStr*)malloc(sizeof(SxRcStr)+n+1); if(!h)exit(1); h->refs=1; h->size=n; h->data[n]=0; return h->data; }\\n"
    "static void sx_rc_retain(const char *p){ if(p){ SxRcStr *h=sx_rc_from(p); if(h->refs==0)abort(); h->refs++; } }\\n"
    "static void sx_rc_release(const char *p){ if(p){ SxRcStr *h=sx_rc_from(p); if(h->refs==0)abort(); if(--h->refs==0)free(h); } }\\n"
    "static double sx_gc_info(void){ return 0.0; }\\n"
    "static double sx_gc(void){ return 0.0; }\\n"
    "static char *sx_concat(const char *a,const char *b){ size_t la=strlen(a),lb=strlen(b); char *r=sx_rc_new(la+lb); memcpy(r,a,la); memcpy(r+la,b,lb); return r; }\\n"
    "static char *sx_str(double n){ char *b=sx_rc_new(64); snprintf(b,65,\\\"%g\\\",n); return b; }\\n";

  if (!replace1(&t, old, neu)) {
    fprintf(stderr, "inject_gc: target string runtime was not found; template unchanged\n");
    free(t);
    return 1;
  }

  /* Keep the public builtins available. Collection is deterministic through
   * reference releases; gc() is only a compatibility no-op. */
  const char *old_call =
    "else if(!strcmp(buf,\\\"concat\\\"))snprintf(call,900,\\\"sx_concat(%s)\\\",args);";
  const char *new_call =
    "else if(!strcmp(buf,\\\"concat\\\"))snprintf(call,900,\\\"sx_concat(%s)\\\",args);"
    "else if(!strcmp(buf,\\\"gc\\\"))snprintf(call,900,\\\"sx_gc()\\\",args);"
    "else if(!strcmp(buf,\\\"gc_info\\\"))snprintf(call,900,\\\"sx_gc_info()\\\",args);"
    "else if(!strcmp(buf,\\\"release\\\"))snprintf(call,900,\\\"(sx_rc_release(%s),0.0)\\\",args);";
  replace1(&t, old_call, new_call);

  FILE *o = fopen("selfhost/stage2_template.c", "wb");
  if (!o) {
    free(t);
    return 1;
  }
  fputs(t, o);
  fclose(o);
  free(t);
  puts("inject_gc: installed single-threaded reference-counted string runtime");
  return 0;
}
