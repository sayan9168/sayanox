#!/usr/bin/env bash
# Step 4.2: when + while via Sayanox codegen
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
chmod +x selfhost/restore_stage2.sh
./selfhost/restore_stage2.sh
CC=clang; command -v clang >/dev/null 2>&1 || CC=gcc

echo "=== when_demo ==="
./selfhost/stage2 selfhost/codegen.sa selfhost/codegen_driver.c
$CC -o selfhost/codegen_bin selfhost/codegen_driver.c
./selfhost/codegen_bin
$CC -o selfhost/codegen_run selfhost/codegen_emit.c
test "$(./selfhost/codegen_run)" = "42"
echo "when OK"

echo "=== while_demo ==="
sed 's/when_demo/while_demo/' selfhost/codegen.sa > selfhost/codegen_while_tmp.sa
./selfhost/stage2 selfhost/codegen_while_tmp.sa selfhost/codegen_driver_w.c
$CC -o selfhost/codegen_bin_w selfhost/codegen_driver_w.c
./selfhost/codegen_bin_w
$CC -o selfhost/codegen_run_w selfhost/codegen_emit.c
test "$(./selfhost/codegen_run_w)" = "42"
echo "while OK"
echo "Step 4.2 OK"
