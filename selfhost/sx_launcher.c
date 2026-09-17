/* Tiny C entry (not Bash). Builds sx_bin from sx.sa if needed, then exec. */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
int main(int argc, char **argv) {
  if (access("selfhost/stage2", X_OK) != 0) {
    system("clang -O2 -o selfhost/build_stage2 selfhost/build_stage2.c && ./selfhost/build_stage2");
  }
  if (access("selfhost/sx_bin", X_OK) != 0) {
    system("./selfhost/stage2 selfhost/sx.sa selfhost/sx_cli.c && clang -O2 -o selfhost/sx_bin selfhost/sx_cli.c");
  }
  char **nargv = calloc((size_t)argc + 1, sizeof(char *));
  if (!nargv) return 1;
  nargv[0] = "sx_bin";
  for (int i = 1; i < argc; i++) nargv[i] = argv[i];
  execv("./selfhost/sx_bin", nargv);
  perror("execv sx_bin");
  return 1;
}
