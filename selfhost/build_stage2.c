/* Stage-2 builder. Prefer local stage2_template.c when valid. */
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

int main(void) {
  int st;
  if (!is_bad_template() && has_chr_helper()) {
    st = system("clang -O2 -o selfhost/stage2 selfhost/stage2_template.c 2>/dev/null");
    if (st != 0)
      st = system("gcc -O2 -o selfhost/stage2 selfhost/stage2_template.c");
    if (st != 0) {
      fprintf(stderr, "build_stage2: compile failed\n");
      return 1;
    }
    puts("Stage-2 built OK (local template + chr/substr)");
    return 0;
  }

  if (is_bad_template()) {
    st = system(
        "cat selfhost/stage2_template_parts/p00.b64 2>/dev/null | tr -d '\\n' | "
        "base64 -d 2>/dev/null | gzip -d > selfhost/stage2_template.c");
    if (st != 0 || is_bad_template()) {
      st = system(
          "cat selfhost/stage2_blob/chunk_00 selfhost/stage2_blob/chunk_01 2>/dev/null | "
          "tr -d '\\n' | base64 -d 2>/dev/null | gzip -d > selfhost/stage2_template.c");
    }
    if (st != 0 || is_bad_template()) {
      fprintf(stderr, "build_stage2: template missing and all bootstrap blobs failed\\n");
      return 1;
    }
  }
  st = system("clang -O2 -o selfhost/stage2 selfhost/stage2_template.c 2>/dev/null");
  if (st != 0)
    st = system("gcc -O2 -o selfhost/stage2 selfhost/stage2_template.c");
  if (st != 0) {
    fprintf(stderr, "build_stage2: compile failed\n");
    return 1;
  }
  puts("Stage-2 built OK");
  return 0;
}
