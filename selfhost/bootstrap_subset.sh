#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[bootstrap] ensure sxc_full seed"
if [ ! -f selfhost/sxc_full.c ]; then
  echo "error: selfhost/sxc_full.c seed is required" >&2
  exit 1
fi
clang -O2 -o selfhost/sxc_full selfhost/sxc_full.c

if [ ! -x selfhost/gen1 ]; then
  echo "[bootstrap] build gen1 from compiler_min.sa via sxc_full"
  ./selfhost/sxc_full selfhost/compiler_min.sa selfhost/gen1.c
  clang -O2 -o selfhost/gen1 selfhost/gen1.c
fi

run_with() {
  local cc=$1 src=$2 expect=$3 label=$4
  "$cc" "$src" selfhost/_out.c
  clang -O2 -o selfhost/_run selfhost/_out.c
  selfhost/_run | grep -q "$expect"
  echo "[OK] $label ($cc)"
}

run_with selfhost/gen1 selfhost/mini_in2.sa 42 "while/when/make"
run_with selfhost/sxc_full selfhost/mini_field.sa 3 "field"
run_with selfhost/sxc_full selfhost/mini_builtin.sa done "builtins"
run_with selfhost/sxc_full selfhost/mini_index.sa 72 "indexing"
run_with selfhost/sxc_full selfhost/mini_in3.sa listok "list+struct"

echo "=== SUBSET-SELFHOST-OK ==="
