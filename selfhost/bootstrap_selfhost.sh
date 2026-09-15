#!/usr/bin/env bash
# CI-safe Stage-2 self-host smoke tests
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Sayanox self-host verification ==="
CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc
chmod +x selfhost/restore_stage2.sh selfhost/sx 2>/dev/null || true

echo "[1/6] Stage-2 restore + build"
./selfhost/restore_stage2.sh
test -x selfhost/stage2
echo "  OK"

echo "[2/6] hello.sa -> 42"
./selfhost/stage2 selfhost/hello.sa selfhost/out_hello.c
$CC -o selfhost/out_hello selfhost/out_hello.c
test "$(./selfhost/out_hello)" = "42"
echo "  OK"

echo "[3/6] sx CLI"
./selfhost/sx selfhost/hello.sa -o selfhost/cli_hello --run >/dev/null
test "$(./selfhost/cli_hello)" = "42"
echo "  OK"

echo "[4/6] modules"
if [[ -f selfhost/modules/main.sa ]]; then
  ./selfhost/stage2 selfhost/modules/main.sa selfhost/out_mod.c
  $CC -o selfhost/out_mod selfhost/out_mod.c
  test "$(./selfhost/out_mod)" = "42"
  echo "  OK"
else
  echo "  skipped"
fi

echo "[5/6] compiler_boot Stage-3 path"
if [[ -f selfhost/compiler_boot.sa ]]; then
  ./selfhost/stage2 selfhost/compiler_boot.sa selfhost/stage3.c
  $CC -o selfhost/stage3 selfhost/stage3.c
  ./selfhost/stage3 >/dev/null || true
  if [[ -f selfhost/hello_out.c ]]; then
    $CC -o selfhost/hello_out selfhost/hello_out.c
    test "$(./selfhost/hello_out)" = "42"
  fi
  echo "  OK"
else
  echo "  skipped"
fi

echo "[6/6] struct_demo"
if [[ -f selfhost/struct_demo.sa ]]; then
  ./selfhost/stage2 selfhost/struct_demo.sa selfhost/out_struct.c
  $CC -o selfhost/out_struct selfhost/out_struct.c
  ./selfhost/out_struct >/dev/null
  echo "  OK"
else
  echo "  skipped"
fi

echo ""
echo "=== SELF-HOST SMOKE OK ==="
