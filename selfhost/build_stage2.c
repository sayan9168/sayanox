/* Stage-2 builder. Prefer local template; fall back to sxc_full.c seed. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int is_bad_template(void) {
  FILE *f = fopen("selfhost/stage2_template.c", "rb");
  char buf[256];
  size_t n;
  if (!f) return 1;
  n = fread(buf, 1, sizeof(buf) - 1, f);
  fclose(f);
  buf[n] = 0;
  if (n < 20) return 1;
  if (strstr(buf, "PLACEHOLDER") != NULL) return 1;
  if (strstr(buf, "#include") == NULL) return 1;
  return 0;
}

static int has_chr_helper(void) {
  FILE *f = fopen("selfhost/stage2_template.c", "rb");
  char *buf;
  long n;
  int ok = 0;
  if (!f) return 0;
  fseek(f, 0, SEEK_END);
  n = ftell(f);
  fseek(f, 0, SEEK_SET);
  buf = malloc((size_t)n + 1);
  if (!buf) { fclose(f); return 0; }
  fread(buf, 1, (size_t)n, f);
  buf[n] = 0;
  fclose(f);
  ok = strstr(buf, "sx_chr") != NULL;
  free(buf);
  return ok;
}

static int compile_stage2(const char *src) {
  char cmd[512];
  int st;
  snprintf(cmd, sizeof(cmd), "clang -O2 -o selfhost/stage2 %s 2>/dev/null", src);
  st = system(cmd);
  if (st != 0) {
    snprintf(cmd, sizeof(cmd), "gcc -O2 -o selfhost/stage2 %s", src);
    st = system(cmd);
  }
  return st;
}

int main(void) {
  int st;
  if (!is_bad_template() && has_chr_helper()) {
    st = compile_stage2("selfhost/stage2_template.c");
    if (st != 0) {
      fprintf(stderr, "build_stage2: compile failed\n");
      return 1;
    }
    puts("Stage-2 built OK (local template)");
    return 0;
  }

  {
    FILE *f = fopen("selfhost/sxc_full.c", "rb");
    if (f) {
      fclose(f);
      st = system("cp selfhost/sxc_full.c selfhost/stage2_template.c");
      if (st == 0) {
        st = compile_stage2("selfhost/stage2_template.c");
        if (st == 0) {
          puts("Stage-2 built OK (from sxc_full.c seed)");
          return 0;
        }
      }
    }
  }

  /* Try decode from sxc_full_b64 */
  st = system(
      "if [ -d selfhost/sxc_full_b64 ]; then "
      "cat selfhost/sxc_full_b64/b*.txt | tr -d '\\n' | base64 -d | gzip -d > selfhost/sxc_full.c; fi");
  {
    FILE *f = fopen("selfhost/sxc_full.c", "rb");
    if (f) {
      fclose(f);
      system("cp selfhost/sxc_full.c selfhost/stage2_template.c");
      st = compile_stage2("selfhost/stage2_template.c");
      if (st == 0) {
        puts("Stage-2 built OK (from sxc_full_b64)");
        return 0;
      }
    }
  }

  fprintf(stderr, "build_stage2: template missing and all bootstrap blobs failed\n");
  return 1;
}
