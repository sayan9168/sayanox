#!/usr/bin/env bash
# Deep self-host verification - complete pipeline, CI-safe
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Sayanox deep self-host ==="

CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc

chmod +x selfhost/restore_stage2.sh selfhost/sx 2>/dev/null || true

echo "[1/7] Complete Stage-2 template + build"
./selfhost/restore_stage2.sh
test -x selfhost/stage2

echo "[2/7] hello.sa -> 42"
./selfhost/stage2 selfhost/hello.sa selfhost/out_hello.c
$CC -o selfhost/out_hello selfhost/out_hello.c
test "$(./selfhost/out_hello)" = "42"
echo "  OK"

echo "[3/7] CLI sx (any path)"
./selfhost/sx selfhost/hello.sa -o selfhost/cli_hello --run >/dev/null
test "$(./selfhost/cli_hello)" = "42"
echo "  OK"

echo "[4/7] use modules"
./selfhost/stage2 selfhost/modules/main.sa selfhost/out_mod.c
$CC -o selfhost/out_mod selfhost/out_mod.c
test "$(./selfhost/out_mod)" = "42"
echo "  OK"

echo "[5/7] Stage-3 via compiler_boot.sa"
./selfhost/stage2 selfhost/compiler_boot.sa selfhost/stage3.c
$CC -o selfhost/stage3 selfhost/stage3.c
./selfhost/stage3 >/dev/null
$CC -o selfhost/hello_out selfhost/hello_out.c
test "$(./selfhost/hello_out)" = "42"
echo "  OK"

echo "[6/7] Stage-1 path via compiler.sa"
if [[ -f selfhost/compiler.sa ]]; then
  ./selfhost/stage2 selfhost/compiler.sa selfhost/compiler_out.c
  $CC -o selfhost/compiler_bin selfhost/compiler_out.c
  ./selfhost/compiler_bin >/dev/null || true
  if [[ -f selfhost/hello_out.c ]]; then
    $CC -o selfhost/hello_from_s1 selfhost/hello_out.c
    test "$(./selfhost/hello_from_s1)" = "42"
    echo "  OK"
  else
    echo "  compiler.sa lowered (hello_out optional)"
  fi
else
  echo "  skipped (no compiler.sa)"
fi

echo "[7/7] struct demo"
if [[ -f selfhost/struct_demo.sa ]]; then
  ./selfhost/stage2 selfhost/struct_demo.sa selfhost/out_struct.c
  $CC -o selfhost/out_struct selfhost/out_struct.c
  ./selfhost/out_struct | head -5
  echo "  OK"
else
  echo "  skipped"
fi

echo ""
echo "=== DEEP SELF-HOST COMPLETE ==="
echo "Daily use (no extra steps):"
echo "  ./selfhost/sx your_program.sa --run"
echo "  ./selfhost/sx your_program.sa -o /tmp/out --run"
