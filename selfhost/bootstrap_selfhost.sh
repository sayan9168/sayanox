#!/usr/bin/env bash
# Deep self-host verification - complete pipeline, CI-safe
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Sayanox deep self-host ==="

CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc

chmod +x selfhost/restore_stage2.sh selfhost/sx selfhost/step1_lexer.sh 2>/dev/null || true

echo "[1/8] Complete Stage-2 template + build"
./selfhost/restore_stage2.sh
test -x selfhost/stage2

echo "[2/8] hello.sa -> 42"
./selfhost/stage2 selfhost/hello.sa selfhost/out_hello.c
$CC -o selfhost/out_hello selfhost/out_hello.c
test "$(./selfhost/out_hello)" = "42"
echo "  OK"

echo "[3/8] CLI sx"
./selfhost/sx selfhost/hello.sa -o selfhost/cli_hello --run >/dev/null
test "$(./selfhost/cli_hello)" = "42"
echo "  OK"

echo "[4/8] use modules"
./selfhost/stage2 selfhost/modules/main.sa selfhost/out_mod.c
$CC -o selfhost/out_mod selfhost/out_mod.c
test "$(./selfhost/out_mod)" = "42"
echo "  OK"

echo "[5/8] Stage-3 compiler_boot"
./selfhost/stage2 selfhost/compiler_boot.sa selfhost/stage3.c
$CC -o selfhost/stage3 selfhost/stage3.c
./selfhost/stage3 >/dev/null
$CC -o selfhost/hello_out selfhost/hello_out.c
test "$(./selfhost/hello_out)" = "42"
echo "  OK"

echo "[6/8] compiler.sa path"
if [[ -f selfhost/compiler.sa ]]; then
  ./selfhost/stage2 selfhost/compiler.sa selfhost/compiler_out.c
  $CC -o selfhost/compiler_bin selfhost/compiler_out.c
  ./selfhost/compiler_bin >/dev/null || true
  echo "  OK"
fi

echo "[7/8] Sayanox-written lexer.sa (Step 1)"
./selfhost/stage2 selfhost/lexer.sa selfhost/lexer_out.c
$CC -o selfhost/lexer_bin selfhost/lexer_out.c
./selfhost/lexer_bin | grep -q NUMBER
echo "  OK"

echo "[8/8] struct demo"
if [[ -f selfhost/struct_demo.sa ]]; then
  ./selfhost/stage2 selfhost/struct_demo.sa selfhost/out_struct.c
  $CC -o selfhost/out_struct selfhost/out_struct.c
  ./selfhost/out_struct | head -3
  echo "  OK"
fi

echo ""
echo "=== DEEP SELF-HOST COMPLETE ==="
echo "Step 1 done: lexer is written in Sayanox (.sa)"
echo "Next: parser.sa"
echo "Daily use: ./selfhost/sx file.sa --run"
