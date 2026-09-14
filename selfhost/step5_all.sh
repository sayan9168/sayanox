#!/usr/bin/env bash
# Full Sayanox-written codegen subset (hold show when while make give)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

chmod +x selfhost/restore_stage2.sh
./selfhost/restore_stage2.sh

python3 selfhost/install_codegen.py

CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc

run_demo() {
  local demo="$1"
  echo "=== $demo ==="
  sed "s/make_demo.sa/${demo}.sa/" selfhost/codegen.sa > selfhost/codegen_run_tmp.sa
  ./selfhost/stage2 selfhost/codegen_run_tmp.sa selfhost/codegen_driver_tmp.c
  $CC -o selfhost/codegen_bin_tmp selfhost/codegen_driver_tmp.c
  ./selfhost/codegen_bin_tmp | grep -q "codegen OK"
  $CC -o selfhost/codegen_out_tmp selfhost/codegen_emit.c
  test "$(./selfhost/codegen_out_tmp)" = "42"
  echo "  OK -> 42"
}

run_demo make_demo
run_demo when_demo
run_demo while_demo
run_demo hold_show

echo "=== ALL SUBSET OK ==="
