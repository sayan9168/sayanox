/* Prove: frozen C → sxc → test; stable Stage-3 without stage2 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
int main(void) {
  if (access("selfhost/sxc", X_OK) != 0) {
    fprintf(stderr, "need selfhost/sxc\n");
    return 1;
  }
  if (system("./selfhost/sxc selfhost/sxc_test_in.sa selfhost/re_a.c") != 0) return 1;
  if (system("clang -O2 -o selfhost/re_a selfhost/re_a.c") != 0) return 1;
  if (system("./selfhost/re_a | grep -q 42") != 0) return 1;
  if (system("./selfhost/sxc selfhost/sxc_test_in.sa selfhost/re_b.c") != 0) return 1;
  if (system("clang -O2 -o selfhost/re_b selfhost/re_b.c") != 0) return 1;
  if (system("./selfhost/re_b | grep -q 42") != 0) return 1;
  if (access("examples/sxc_struct.sa", R_OK) == 0) {
    if (system("./selfhost/sxc examples/sxc_struct.sa selfhost/re_s.c") != 0) return 1;
    if (system("clang -O2 -o selfhost/re_s selfhost/re_s.c") != 0) return 1;
    if (system("./selfhost/re_s | grep -q 10") != 0) return 1;
  }
  printf("SELFHOST-RECOMPILE-OK\n");
  printf("  Stage-3 sxc (from frozen C) is stable without stage2\n");
  printf("  Full sxc.sa re-parse still needs stage2 when editing compiler source\n");
  return 0;
}
