#!/usr/bin/env bash
# Step 2: Sayanox-written parser
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
chmod +x selfhost/restore_stage2.sh
./selfhost/restore_stage2.sh
echo "Compiling parser.sa..."
./selfhost/stage2 selfhost/parser.sa selfhost/parser_out.c
CC=clang; command -v clang >/dev/null 2>&1 || CC=gcc
$CC -o selfhost/parser_bin selfhost/parser_out.c
echo "Running parser:"
./selfhost/parser_bin
