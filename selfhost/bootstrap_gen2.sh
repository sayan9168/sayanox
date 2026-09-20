#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Sayanox true self-compile ==="

if [ ! -x selfhost/sxc_full ]; then
  if [ ! -f selfhost/sxc_full.c ]; then
    echo "error: selfhost/sxc_full is missing and selfhost/sxc_full.c is unavailable" >&2
    exit 1
  fi
  clang -O2 -o selfhost/sxc_full selfhost/sxc_full.c
fi

echo "[1] Build gen1 from compiler_min.sa"
./selfhost/sxc_full selfhost/compiler_min.sa selfhost/gen1.c
clang -O2 -o selfhost/gen1 selfhost/gen1.c

echo "[2] Gen1 compiles compiler_min.sa into gen2.c"
rm -f selfhost/gen2.c selfhost/gen2
timeout 120 ./selfhost/gen1 selfhost/compiler_min.sa selfhost/gen2.c
test -s selfhost/gen2.c

echo "[3] Build gen2"
clang -O2 -o selfhost/gen2 selfhost/gen2.c

echo "[4] Gen1 and gen2 compile mini_in2 with identical runtime output"
rm -f selfhost/gen1_mini.c selfhost/gen2_mini.c selfhost/gen1_mini selfhost/gen2_mini
./selfhost/gen1 selfhost/mini_in2.sa selfhost/gen1_mini.c
./selfhost/gen2 selfhost/mini_in2.sa selfhost/gen2_mini.c
clang -O2 -o selfhost/gen1_mini selfhost/gen1_mini.c
clang -O2 -o selfhost/gen2_mini selfhost/gen2_mini.c
./selfhost/gen1_mini > /tmp/sayanox-gen1.out
./selfhost/gen2_mini > /tmp/sayanox-gen2.out
diff -u /tmp/sayanox-gen1.out /tmp/sayanox-gen2.out

echo "[5] Existing mini regression tests"
for test_src in mini_in2 mini_field mini_builtin mini_index mini_in3; do
  ./selfhost/gen1 "selfhost/$test_src.sa" "selfhost/${test_src}_gen2.c"
  clang -O2 -o "selfhost/${test_src}_gen2" "selfhost/${test_src}_gen2.c"
  "./selfhost/${test_src}_gen2" >/dev/null
done

echo "=== TRUE-SELF-COMPILE-OK ==="
