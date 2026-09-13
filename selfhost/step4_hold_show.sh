#!/usr/bin/env bash
# Step 4.1: hold + show via Sayanox codegen.sa
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
chmod +x selfhost/restore_stage2.sh
./selfhost/restore_stage2.sh

./selfhost/stage2 selfhost/codegen.sa selfhost/codegen_driver.c
CC=clang; command -v clang >/dev/null 2>&1 || CC=gcc
$CC -o selfhost/codegen_bin selfhost/codegen_driver.c
./selfhost/codegen_bin
$CC -o selfhost/codegen_run selfhost/codegen_emit.c
echo "emitted run:"
./selfhost/codegen_run
test "$(./selfhost/codegen_run)" = "42"
echo "Step 4.1 OK"
