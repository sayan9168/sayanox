/* Prove Stage-3 closed loop: sxc compiles tests without stage2 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
int main(void) {
  if (access("selfhost/sxc", X_OK) != 0) {
    fprintf(stderr, "prove: need selfhost/sxc (make selfhost-fast)\n");
    return 1;
  }
  if (system("./selfhost/sxc selfhost/sxc_test_in.sa selfhost/loop_emit.c") != 0) return 1;
  if (system("clang -O2 -o selfhost/loop_run selfhost/loop_emit.c") != 0) return 1;
  if (system("./selfhost/loop_run | grep -q 42") != 0) return 1;
  if (access("examples/sxc_struct.sa", R_OK) == 0) {
    if (system("./selfhost/sxc examples/sxc_struct.sa selfhost/loop_struct.c") != 0) return 1;
    if (system("clang -O2 -o selfhost/loop_struct selfhost/loop_struct.c") != 0) return 1;
    if (system("./selfhost/loop_struct | grep -q 10") != 0) return 1;
  }
  printf("SELFHOST-LOOP-OK\n");
  printf("  sxc (from frozen C) compiles tests without stage2\n");
  printf("  regenerating sxc.sa still uses stage2 when source changes\n");
  return 0;
}
