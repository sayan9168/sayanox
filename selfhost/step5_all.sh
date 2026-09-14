#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
chmod +x selfhost/restore_stage2.sh
./selfhost/restore_stage2.sh
python3 selfhost/install_codegen.py
CC=clang; command -v clang >/dev/null 2>&1 || CC=gcc
run_demo() {
  local demo="$1" expect="${2:-42}"
  echo "=== $demo ==="
  sed "s/multivar_demo.sa/${demo}.sa/" selfhost/codegen.sa > selfhost/codegen_run_tmp.sa
  ./selfhost/stage2 selfhost/codegen_run_tmp.sa selfhost/codegen_driver_tmp.c
  $CC -o selfhost/codegen_bin_tmp selfhost/codegen_driver_tmp.c
  ./selfhost/codegen_bin_tmp | grep -q "codegen OK"
  $CC -o selfhost/codegen_out_tmp selfhost/codegen_emit.c
  local out
  out="$(./selfhost/codegen_out_tmp | tr '\n' ' ' | sed 's/ *$//')"
  echo "  got: $out"
  if [[ "$demo" == "multivar_demo" ]]; then
    echo "$out" | grep -q "10"
    echo "$out" | grep -q "32"
  else
    test "$out" = "$expect" -o "$out" = "42"
  fi
  echo "  OK"
}
run_demo multivar_demo
run_demo otherwise_demo
run_demo make_demo
run_demo when_demo
run_demo while_demo
run_demo hold_show
echo "=== EXPANDED SUBSET OK ==="
echo "Bootstrap note: Stage-2 C runs .sa tools; logic above is in Sayanox."
