#!/usr/bin/env bash
# Step 3: Sayanox-written codegen (parse + emit C + run)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
chmod +x selfhost/restore_stage2.sh
./selfhost/restore_stage2.sh

echo "Compiling codegen.sa with Stage-2..."
./selfhost/stage2 selfhost/codegen.sa selfhost/codegen_driver.c
CC=clang; command -v clang >/dev/null 2>&1 || CC=gcc
$CC -o selfhost/codegen_bin selfhost/codegen_driver.c

echo "Running codegen.sa (emits C)..."
./selfhost/codegen_bin

echo "Compiling emitted C..."
$CC -o selfhost/codegen_run selfhost/codegen_emit.c
echo "Running emitted binary:"
./selfhost/codegen_run
test "$(./selfhost/codegen_run)" = "42"
echo "Step 3 OK"
