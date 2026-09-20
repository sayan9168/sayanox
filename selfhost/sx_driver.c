/* Unified Sayanox driver: native AOT or C/selfhost backend */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

static int run(const char *cmd) {
  fprintf(stderr, "sx: %s\n", cmd);
  int st = system(cmd);
  if (st == -1) return 1;
  if (WIFEXITED(st)) return WEXITSTATUS(st);
  return 1;
}

static int file_ok(const char *p) { return access(p, X_OK) == 0; }

static void usage(const char *a0) {
  fprintf(stderr,
    "Usage: %s [--backend=auto|native|c] [-o out] input.sa\n"
    "  auto    try native ELF, else sxc -> C -> clang (default)\n"
    "  native  direct x86-64 ELF via native_aot\n"
    "  c       Stage-3 sxc emits C, then clang\n",
    a0);
}

int main(int argc, char **argv) {
  const char *backend = "auto";
  const char *out = NULL;
  const char *in = NULL;
  for (int i = 1; i < argc; i++) {
    if (!strncmp(argv[i], "--backend=", 10)) backend = argv[i] + 10;
    else if (!strcmp(argv[i], "-o") && i + 1 < argc) out = argv[++i];
    else if (argv[i][0] == '-') {
      usage(argv[0]);
      return 2;
    } else in = argv[i];
  }
  if (!in) {
    usage(argv[0]);
    return 2;
  }
  char bin[512];
  if (!out) {
    snprintf(bin, sizeof(bin), "%s", in);
    char *dot = strrchr(bin, '.');
    if (dot && !strcmp(dot, ".sa")) *dot = 0;
    else strncat(bin, ".out", sizeof(bin) - strlen(bin) - 1);
    out = bin;
  }

  int use_native = 0;
  if (!strcmp(backend, "native")) use_native = 1;
  else if (!strcmp(backend, "c")) use_native = 0;
  else {
    use_native = file_ok("selfhost/native_aot") || file_ok("./selfhost/native_aot");
  }

  char cmd[2048];
  if (use_native) {
    const char *na = file_ok("selfhost/native_aot") ? "selfhost/native_aot" : "./selfhost/native_aot";
    if (!file_ok(na)) {
      fprintf(stderr, "sx: native_aot missing; run `make native` or use --backend=c\n");
      return 1;
    }
    snprintf(cmd, sizeof(cmd), "%s %s %s", na, in, out);
    int rc = run(cmd);
    if (rc != 0) return rc;
    fprintf(stderr, "sx: backend=native -> %s\n", out);
    return 0;
  }

  const char *sxc = file_ok("selfhost/sxc") ? "selfhost/sxc" : "./selfhost/sxc";
  if (!file_ok(sxc)) {
    fprintf(stderr, "sx: sxc missing; run `make selfhost-fast` or `make selfhost`\n");
    return 1;
  }
  char cfile[512];
  snprintf(cfile, sizeof(cfile), "%s.c", out);
  snprintf(cmd, sizeof(cmd), "%s %s %s", sxc, in, cfile);
  int rc = run(cmd);
  if (rc != 0) return rc;
  snprintf(cmd, sizeof(cmd), "clang -O2 -pthread -o %s %s", out, cfile);
  rc = run(cmd);
  if (rc != 0) return rc;
  fprintf(stderr, "sx: backend=c -> %s\n", out);
  return 0;
}
