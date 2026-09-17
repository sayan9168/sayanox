/* Stage-2 builder. Rebuilds template if missing or PLACEHOLDER. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int is_bad_template(void) {
  FILE *f = fopen("selfhost/stage2_template.c", "rb");
  char buf[64];
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

int main(void) {
  int st;
  const char *url =
      "https://raw.githubusercontent.com/sayan9168/sayanox/"
      "bef338f0cc1344fa0167b64b827f2409dddb8200/selfhost/stage2_template.c";

  if (is_bad_template()) {
    char cmd[1400];
    st = system(
        "cat selfhost/stage2_blob/part0.b64 selfhost/stage2_blob/part1.b64 "
        "selfhost/stage2_blob/part2.b64 2>/dev/null | tr -d '\\n' | "
        "base64 -d 2>/dev/null | gzip -d > selfhost/stage2_template.c");
    if (st != 0 || is_bad_template()) {
      snprintf(cmd, sizeof(cmd), "curl -fsSL '%s' -o selfhost/stage2_template.c", url);
      st = system(cmd);
      if (st != 0) {
        fprintf(stderr, "build_stage2: cannot fetch stage2_template.c\n");
        return 1;
      }
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
