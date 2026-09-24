/* fixup_emit: turn double/char* redeclarations into assignments */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

static int is_id_start(int c) { return isalpha(c) || c == '_'; }
static int is_id(int c) { return isalnum(c) || c == '_'; }

int main(int argc, char **argv) {
  if (argc < 3) {
    fprintf(stderr, "usage: fixup_emit in.c out.c\n");
    return 1;
  }
  FILE *f = fopen(argv[1], "rb");
  if (!f) { perror(argv[1]); return 1; }
  fseek(f, 0, SEEK_END);
  long n = ftell(f);
  fseek(f, 0, SEEK_SET);
  char *src = malloc((size_t)n + 1);
  fread(src, 1, (size_t)n, f);
  src[n] = 0;
  fclose(f);

  char declared[512][64];
  int nd = 0;
  FILE *o = fopen(argv[2], "wb");
  if (!o) { perror(argv[2]); return 1; }

  char *p = src;
  while (*p) {
    char *line = p;
    while (*p && *p != '\n') p++;
    int len = (int)(p - line);
    char buf[4096];
    if (len >= (int)sizeof(buf)) len = (int)sizeof(buf) - 1;
    memcpy(buf, line, (size_t)len);
    buf[len] = 0;

    char *s = buf;
    while (*s == ' ' || *s == '\t') s++;
    int is_decl = 0;
    char name[64];
    name[0] = 0;
    if (strncmp(s, "double ", 7) == 0) {
      s += 7;
      while (*s == ' ') s++;
      if (is_id_start((unsigned char)*s)) {
        int i = 0;
        while (is_id((unsigned char)*s) && i < 63) name[i++] = *s++;
        name[i] = 0;
        while (*s == ' ') s++;
        if (*s == '=') is_decl = 1;
      }
    } else if (strncmp(s, "char *", 6) == 0) {
      s += 6;
      while (*s == ' ') s++;
      if (is_id_start((unsigned char)*s)) {
        int i = 0;
        while (is_id((unsigned char)*s) && i < 63) name[i++] = *s++;
        name[i] = 0;
        while (*s == ' ') s++;
        if (*s == '=') is_decl = 1;
      }
    }

    if (is_decl && name[0]) {
      int known = 0;
      for (int i = 0; i < nd; i++)
        if (strcmp(declared[i], name) == 0) { known = 1; break; }
      if (known) {
        char *eq = strchr(buf, '=');
        fprintf(o, "  %s %s\n", name, eq);
      } else {
        if (nd < 512) {
          strncpy(declared[nd], name, 63);
          declared[nd][63] = 0;
          nd++;
        }
        fwrite(line, 1, (size_t)(p - line), o);
        if (*p == '\n') fputc('\n', o);
      }
    } else {
      fwrite(line, 1, (size_t)(p - line), o);
      if (*p == '\n') fputc('\n', o);
    }
    if (*p == '\n') p++;
  }
  fclose(o);
  free(src);
  return 0;
}
