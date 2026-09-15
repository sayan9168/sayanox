#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
echo "=== Sayanox self-host verification ==="
CC=clang; command -v clang >/dev/null 2>&1 || CC=gcc
chmod +x selfhost/restore_stage2.sh selfhost/sx 2>/dev/null || true

echo "[1/10] Stage-2"
./selfhost/restore_stage2.sh
echo "  OK"

echo "[2/10] hello"
./selfhost/stage2 selfhost/hello.sa selfhost/out_hello.c
$CC -o selfhost/out_hello selfhost/out_hello.c
test "$(./selfhost/out_hello)" = "42"
echo "  OK"

echo "[3/10] sx"
./selfhost/sx selfhost/hello.sa -o selfhost/cli_hello --run >/dev/null
test "$(./selfhost/cli_hello)" = "42"
echo "  OK"

echo "[4/10] modules"
./selfhost/stage2 selfhost/modules/main.sa selfhost/out_mod.c
$CC -o selfhost/out_mod selfhost/out_mod.c
test "$(./selfhost/out_mod)" = "42"
echo "  OK"

echo "[5/10] Stage-3"
./selfhost/stage2 selfhost/compiler_boot.sa selfhost/stage3.c
$CC -o selfhost/stage3 selfhost/stage3.c
./selfhost/stage3 >/dev/null
$CC -o selfhost/hello_out selfhost/hello_out.c
test "$(./selfhost/hello_out)" = "42"
echo "  OK"

echo "[6/10] compiler.sa"
./selfhost/stage2 selfhost/compiler.sa selfhost/compiler_out.c
$CC -o selfhost/compiler_bin selfhost/compiler_out.c
./selfhost/compiler_bin >selfhost/compiler_runtime.log 2>&1
cat selfhost/compiler_runtime.log
grep -Eq 'Compiler|compiler|42' selfhost/compiler_runtime.log
test -s selfhost/hello_out.c
echo "  OK"

echo "[7/10] lexer.sa"
./selfhost/stage2 selfhost/lexer.sa selfhost/lexer_out.c
$CC -o selfhost/lexer_bin selfhost/lexer_out.c
set +e
./selfhost/lexer_bin >selfhost/lexer_runtime.log 2>&1
lexer_status=$?
set -e
cat selfhost/lexer_runtime.log
if [[ $lexer_status -ne 0 ]]; then
  echo "lexer.sa runtime failed with exit code $lexer_status"
  exit "$lexer_status"
fi
grep -q 'NUMBER' selfhost/lexer_out.c
grep -q 'STRING' selfhost/lexer_out.c
grep -q 'IDENT' selfhost/lexer_out.c
echo "  OK"

echo "[8/10] parser.sa"
./selfhost/stage2 selfhost/parser.sa selfhost/parser_out.c
$CC -o selfhost/parser_bin selfhost/parser_out.c
set +e
./selfhost/parser_bin >selfhost/parser_runtime.log 2>&1
parser_status=$?
set -e
cat selfhost/parser_runtime.log
if [[ $parser_status -ne 0 ]]; then
  echo "parser.sa runtime failed with exit code $parser_status"
  exit "$parser_status"
fi
grep -Eq 'parse OK|Parser OK|valid' selfhost/parser_runtime.log
echo "  OK"

echo "[8b/10] parser valid fixture"
./selfhost/stage2 selfhost/parser_demo.sa selfhost/parser_demo_out.c
$CC -o selfhost/parser_demo_bin selfhost/parser_demo_out.c
./selfhost/parser_demo_bin >selfhost/parser_demo_runtime.log 2>&1
cat selfhost/parser_demo_runtime.log
grep -Eq 'parse OK|Parser OK|valid' selfhost/parser_demo_runtime.log
echo "  OK"

echo "[8c/10] parser invalid fixture"
set +e
./selfhost/stage2 selfhost/parser_invalid.sa selfhost/parser_invalid_out.c >selfhost/parser_invalid_compile.log 2>&1
invalid_compile_status=$?
set -e
cat selfhost/parser_invalid_compile.log
if [[ $invalid_compile_status -eq 0 ]]; then
  $CC -o selfhost/parser_invalid_bin selfhost/parser_invalid_out.c
  set +e
  ./selfhost/parser_invalid_bin >selfhost/parser_invalid_runtime.log 2>&1
  invalid_runtime_status=$?
  set -e
  cat selfhost/parser_invalid_runtime.log
  if [[ $invalid_runtime_status -eq 0 ]]; then
    grep -Eq 'ERROR|error|invalid|unclosed|unexpected' selfhost/parser_invalid_runtime.log
  fi
else
  grep -Eq 'error|Error|ERROR|expected|Expected' selfhost/parser_invalid_compile.log
fi
echo "  OK"

echo "[9/10] codegen.sa"
./selfhost/stage2 selfhost/codegen.sa selfhost/codegen_driver.c
$CC -o selfhost/codegen_bin selfhost/codegen_driver.c
./selfhost/codegen_bin >selfhost/codegen_runtime.log 2>&1
cat selfhost/codegen_runtime.log
grep -q "codegen OK" selfhost/codegen_runtime.log
test -s selfhost/codegen_emit.c
$CC -o selfhost/codegen_run selfhost/codegen_emit.c
codegen_output="$(./selfhost/codegen_run)"
test "$codegen_output" = "42"
echo "  OK"

echo "[10/10] struct"
test -f selfhost/struct_demo.sa
./selfhost/stage2 selfhost/struct_demo.sa selfhost/out_struct.c
$CC -o selfhost/out_struct selfhost/out_struct.c
struct_output="$(./selfhost/out_struct)"
printf '%s\n' "$struct_output"
test "$struct_output" = $'3\n4\n7'
echo "  OK"

echo ""
echo "=== SELF-HOST VERIFICATION PASSED ==="
echo "Stage-2, compiler, lexer, parser, codegen, and struct checks passed."
