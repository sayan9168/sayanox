/* Inject sx_chr / sx_substr into stage2_template.c if missing. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
  FILE *f = fopen("selfhost/stage2_template.c", "rb");
  long n; char *t;
  if (!f) { fprintf(stderr, "inject_chr: no template\n"); return 1; }
  fseek(f, 0, SEEK_END); n = ftell(f); fseek(f, 0, SEEK_SET);
  t = malloc((size_t)n + 1); fread(t, 1, (size_t)n, f); t[n] = 0; fclose(f);
  if (strstr(t, "sx_chr")) { puts("inject_chr: already present"); free(t); return 0; }

  {
    const char *old_looks = "strstr(e,\"sx_trim\")?1:0;";
    const char *new_looks = "strstr(e,\"sx_trim\")||strstr(e,\"sx_chr\")||strstr(e,\"sx_substr\")?1:0;";
    char *q = strstr(t, old_looks);
    if (q) {
      size_t before = (size_t)(q - t);
      size_t oldlen = strlen(old_looks);
      size_t after = strlen(q + oldlen);
      char *nt = malloc(before + strlen(new_looks) + after + 1);
      memcpy(nt, t, before);
      memcpy(nt + before, new_looks, strlen(new_looks));
      memcpy(nt + before + strlen(new_looks), q + oldlen, after + 1);
      free(t); t = nt; n = (long)strlen(t);
    }
  }
  {
    const char *old_c = "else if(!strcmp(buf,\"concat\"))snprintf(call,900,\"sx_concat(%s)\",args);";
    const char *new_c = "else if(!strcmp(buf,\"concat\"))snprintf(call,900,\"sx_concat(%s)\",args);else if(!strcmp(buf,\"chr\"))snprintf(call,900,\"sx_chr(%s)\",args);else if(!strcmp(buf,\"substr\"))snprintf(call,900,\"sx_substr(%s)\",args);";
    char *q = strstr(t, old_c);
    if (q && !strstr(t, "sx_chr(%s)")) {
      size_t before = (size_t)(q - t);
      size_t oldlen = strlen(old_c);
      size_t after = strlen(q + oldlen);
      char *nt = malloc(before + strlen(new_c) + after + 1);
      memcpy(nt, t, before);
      memcpy(nt + before, new_c, strlen(new_c));
      memcpy(nt + before + strlen(new_c), q + oldlen, after + 1);
      free(t); t = nt; n = (long)strlen(t);
    }
  }
  {
    char *last = NULL; char *s = t;
    while ((s = strstr(s, "return r; }\\n\";")) != NULL) { last = s; s += 10; }
    if (last) {
      const char *inject = "return r; }\\nstatic char *sx_chr(double code){ char *r=malloc(2); if(!r)exit(1); r[0]=(char)((int)code & 255); r[1]=0; return r; }\\nstatic char *sx_substr(const char *s, double start, double length){ size_t n=strlen(s); int i=(int)start; int L=(int)length; if(i<0)i=0; if((size_t)i>n)i=(int)n; if(L<0)L=0; if((size_t)i+(size_t)L>n)L=(int)(n-(size_t)i); char *r=malloc((size_t)L+1); if(!r)exit(1); memcpy(r,s+(size_t)i,(size_t)L); r[L]=0; return r; }\\n\";";
      size_t before = (size_t)(last - t);
      size_t oldlen = strlen("return r; }\\n\";");
      size_t after = strlen(last + oldlen);
      char *nt = malloc(before + strlen(inject) + after + 1);
      memcpy(nt, t, before);
      memcpy(nt + before, inject, strlen(inject));
      memcpy(nt + before + strlen(inject), last + oldlen, after + 1);
      free(t); t = nt;
    }
  }

  f = fopen("selfhost/stage2_template.c", "wb");
  if (!f) { free(t); return 1; }
  fwrite(t, 1, strlen(t), f);
  fclose(f);
  free(t);
  puts("inject_chr: patched template");
  return 0;
}
