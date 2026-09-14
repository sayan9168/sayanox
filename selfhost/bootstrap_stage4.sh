#!/usr/bin/env bash
# Sayanox Stage-4 bootstrap verification.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc

chmod +x selfhost/restore_stage2.sh selfhost/sx
./selfhost/restore_stage2.sh

rm -f selfhost/stage4_lexer.c selfhost/stage4_parser.c selfhost/stage4_ast.c selfhost/stage4_typecheck.c selfhost/stage4_bootstrap.c

echo "=== Stage-4 Self-Hosted Toolchain ==="
echo "[1/5] Lexer"
./selfhost/stage2 selfhost/lexer.sa selfhost/stage4_lexer.c
$CC -o selfhost/stage4_lexer selfhost/stage4_lexer.c
./selfhost/stage4_lexer | grep -q NUMBER

echo "[2/5] Parser"
./selfhost/stage2 selfhost/parser.sa selfhost/stage4_parser.c
$CC -o selfhost/stage4_parser selfhost/stage4_parser.c
./selfhost/stage4_parser | grep -q "parse OK"

echo "[3/5] AST"
./selfhost/stage2 selfhost/ast.sa selfhost/stage4_ast.c
$CC -o selfhost/stage4_ast selfhost/stage4_ast.c
./selfhost/stage4_ast | grep -q "AST root"

echo "[4/5] Type checker"
./selfhost/stage2 selfhost/typecheck.sa selfhost/stage4_typecheck.c
$CC -o selfhost/stage4_typecheck selfhost/stage4_typecheck.c
./selfhost/stage4_typecheck | grep -q "errors"

echo "[5/5] Stage-4 coordinator"
./selfhost/stage2 selfhost/stage4_bootstrap.sa selfhost/stage4_bootstrap.c
$CC -o selfhost/stage4_bootstrap selfhost/stage4_bootstrap.c
./selfhost/stage4_bootstrap | grep -q "Stage-4 bootstrap complete"

echo "=== Stage-4 Self-Hosted Toolchain COMPLETE ==="
