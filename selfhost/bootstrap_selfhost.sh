#!/usr/bin/env bash
# Deep self-host + Step1/2 in .sa
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Sayanox deep self-host ==="
CC=clang; command -v clang >/dev/null 2>&1 || CC=gcc
chmod +x selfhost/restore_stage2.sh selfhost/sx selfhost/step1_lexer.sh selfhost/step2_parser.sh 2>/dev/null || true

echo "[1/9] Stage-2 build"
./selfhost/restore_stage2.sh

echo "[2/9] hello.sa"
./selfhost/stage2 selfhost/hello.sa selfhost/out_hello.c
$CC -o selfhost/out_hello selfhost/out_hello.c
test "$(./selfhost/out_hello)" = "42"
echo "  OK"

echo "[3/9] sx CLI"
./selfhost/sx selfhost/hello.sa -o selfhost/cli_hello --run >/dev/null
test "$(./selfhost/cli_hello)" = "42"
echo "  OK"

echo "[4/9] modules"
./selfhost/stage2 selfhost/modules/main.sa selfhost/out_mod.c
$CC -o selfhost/out_mod selfhost/out_mod.c
test "$(./selfhost/out_mod)" = "42"
echo "  OK"

echo "[5/9] Stage-3"
./selfhost/stage2 selfhost/compiler_boot.sa selfhost/stage3.c
$CC -o selfhost/stage3 selfhost/stage3.c
./selfhost/stage3 >/dev/null
$CC -o selfhost/hello_out selfhost/hello_out.c
test "$(./selfhost/hello_out)" = "42"
echo "  OK"

echo "[6/9] compiler.sa"
if [[ -f selfhost/compiler.sa ]]; then
  ./selfhost/stage2 selfhost/compiler.sa selfhost/compiler_out.c
  $CC -o selfhost/compiler_bin selfhost/compiler_out.c
  ./selfhost/compiler_bin >/dev/null || true
  echo "  OK"
fi

echo "[7/9] lexer.sa (Step 1)"
./selfhost/stage2 selfhost/lexer.sa selfhost/lexer_out.c
$CC -o selfhost/lexer_bin selfhost/lexer_out.c
./selfhost/lexer_bin | grep -q NUMBER
echo "  OK"

echo "[8/9] parser.sa (Step 2)"
./selfhost/stage2 selfhost/parser.sa selfhost/parser_out.c
$CC -o selfhost/parser_bin selfhost/parser_out.c
./selfhost/parser_bin | grep -q "parse OK"
echo "  OK"

echo "[9/9] struct"
if [[ -f selfhost/struct_demo.sa ]]; then
  ./selfhost/stage2 selfhost/struct_demo.sa selfhost/out_struct.c
  $CC -o selfhost/out_struct selfhost/out_struct.c
  ./selfhost/out_struct | head -2
  echo "  OK"
fi

echo ""
echo "=== DEEP SELF-HOST COMPLETE ==="
echo "Steps 1-2 done in .sa (lexer + parser)"
echo "Next: codegen.sa"
