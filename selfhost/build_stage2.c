/* Build Stage-2 without Bash. clang -O2 -o build_stage2 build_stage2.c && ./build_stage2 */
#include <stdio.h>
#include <stdlib.h>
int main(void) {
  int st;
  st = system("test -f selfhost/stage2_template.c");
  if (st != 0) {
    fprintf(stderr, "build_stage2: missing selfhost/stage2_template.c\n");
    return 1;
  }
  st = system("clang -O2 -o selfhost/stage2 selfhost/stage2_template.c 2>/dev/null");
  if (st != 0)
    st = system("gcc -O2 -o selfhost/stage2 selfhost/stage2_template.c");
  if (st != 0) {
    fprintf(stderr, "build_stage2: compile failed\n");
    return 1;
  }
  puts("Stage-2 built OK (no Bash)");
  return 0;
}
