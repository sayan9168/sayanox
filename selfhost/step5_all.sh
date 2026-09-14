#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
chmod +x selfhost/restore_stage2.sh
./selfhost/restore_stage2.sh
python3 selfhost/install_codegen.py
CC=clang; command -v clang >/dev/null 2>&1 || CC=gcc
run_demo() {
  local demo="$1"
  echo "=== $demo ==="
  sed "s/fullname_demo.sa/${demo}.sa/" selfhost/codegen.sa > selfhost/codegen_run_tmp.sa
  ./selfhost/stage2 selfhost/codegen_run_tmp.sa selfhost/codegen_driver_tmp.c
  $CC -o selfhost/codegen_bin_tmp selfhost/codegen_driver_tmp.c
  ./selfhost/codegen_bin_tmp | grep -q "codegen OK"
  $CC -o selfhost/codegen_out_tmp selfhost/codegen_emit.c
  echo -n "  out: "
  ./selfhost/codegen_out_tmp | tr '\n' ' '
  echo
}
run_demo fullname_demo
run_demo string_demo
run_demo list_demo
echo "=== OK ==="
