#!/usr/bin/env bash
# Step 1: build and run the Sayanox-written lexer
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

chmod +x selfhost/restore_stage2.sh
./selfhost/restore_stage2.sh

echo "Compiling lexer.sa with Stage-2..."
./selfhost/stage2 selfhost/lexer.sa selfhost/lexer_out.c

CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc
$CC -o selfhost/lexer_bin selfhost/lexer_out.c

echo "Running lexer on selfhost/hello.sa:"
./selfhost/lexer_bin
