#!/usr/bin/env bash
# Stage-3 self-host bootstrap and end-to-end smoke test.
#
# Bootstrap chain:
#   Stage-2 compiler -> compiler_boot.sa -> stage3 bootstrap compiler
#   Stage-2 compiler -> compiler.sa      -> stage3 self-host compiler
#   stage3 self-host compiler -> hello.sa -> generated C -> native binary
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc

rm -f selfhost/stage3.c selfhost/stage3 selfhost/stage3_compiler.c \
      selfhost/stage3_compiler selfhost/hello_out.c selfhost/hello_out \
      selfhost/stage2_cc.c selfhost/cli_hello.c selfhost/cli_struct.c \
      selfhost/cli_hello selfhost/cli_struct

echo "=== Sayanox Stage-3 Self-Hosting ==="

# Always restore the known-good Stage-2 compiler. This keeps Stage-3
# reproducible and avoids relying on a stale generated binary.
chmod +x selfhost/restore_stage2.sh selfhost/sx
./selfhost/restore_stage2.sh

# Stage-2 -> bootstrap compiler.
echo "[1/4] Stage-2 -> compiler_boot.sa"
./selfhost/stage2 selfhost/compiler_boot.sa selfhost/stage3.c
$CC -o selfhost/stage3 selfhost/stage3.c
./selfhost/stage3

test -s selfhost/hello_out.c
grep -q 'puts("42")' selfhost/hello_out.c
$CC -o selfhost/hello_out selfhost/hello_out.c
printf '[bootstrap output] '
./selfhost/hello_out

# Stage-2 -> the larger Sayanox compiler source.
echo "[2/4] Stage-2 -> compiler.sa"
./selfhost/stage2 selfhost/compiler.sa selfhost/stage3_compiler.c
$CC -o selfhost/stage3_compiler selfhost/stage3_compiler.c

# The compiler produced from Sayanox source must itself execute and emit
# another valid C program plus the next-stage compiler payload.
echo "[3/4] Stage-3 compiler -> hello.sa"
./selfhost/stage3_compiler

test -s selfhost/hello_out.c
test -s selfhost/stage2_cc.c
grep -q 'puts("42")' selfhost/hello_out.c
grep -q 'TokKind\|compile_generic' selfhost/stage2_cc.c
$CC -o selfhost/hello_out selfhost/hello_out.c
printf '[stage3 output] '
./selfhost/hello_out

# Keep the public CLI smoke tests in the same bootstrap contract.
echo "[4/4] CLI smoke tests"
./selfhost/sx selfhost/hello.sa -o selfhost/cli_hello --run
./selfhost/sx selfhost/struct_demo.sa -o selfhost/cli_struct --run

echo "=== Stage-3 Self-Hosting COMPLETE ==="
