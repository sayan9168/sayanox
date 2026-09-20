#!/bin/bash
set -e
cd "$(dirname "$0")/.."
echo "=== Sayanox complete feature + self-host subset ==="
clang -O2 -o selfhost/sxc_full selfhost/sxc_full.c
./selfhost/sxc_full selfhost/compiler_min.sa selfhost/gen1.c
clang -O2 -o selfhost/gen1 selfhost/gen1.c
echo "[Gen1] built from pure .sa"

run_test() {
  local src="$1" expect="$2" label="$3"
  ./selfhost/gen1 "$src" selfhost/_out.c
  clang -O2 -o selfhost/_run selfhost/_out.c
  selfhost/_run | grep -q "$expect"
  echo "[OK] $label"
}

run_test selfhost/mini_in2.sa 42 "while/when/make"
run_test selfhost/mini_field.sa 3 "field access"
run_test selfhost/mini_builtin.sa done "builtins"
run_test selfhost/mini_index.sa 72 "string indexing"
run_test selfhost/mini_in3.sa listok "list+struct"

echo "=== ALL-COMPLETE-OK ==="
