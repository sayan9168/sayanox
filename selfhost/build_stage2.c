/* Stage-2 builder - no Bash. Assembles template from stage2_blob parts */
#include <stdio.h>
#include <stdlib.h>
int main(void) {
  int st;
  if (system("test -f selfhost/stage2_template.c") != 0) {
    st = system(
      "cat selfhost/stage2_blob/part0.b64 selfhost/stage2_blob/part1.b64 "
      "selfhost/stage2_blob/part2.b64 2>/dev/null | tr -d '\\n' | "
      "base64 -d 2>/dev/null | gzip -d > selfhost/stage2_template.c");
    if (st != 0) {
      fprintf(stderr, "build_stage2: cannot decode stage2_blob\n");
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
  puts("Stage-2 built OK (Sayanox path, no Bash scripts)");
  return 0;
}
