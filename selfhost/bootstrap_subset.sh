#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[bootstrap] restore sxc_full seed"
chmod +x selfhost/restore_sxc_full.sh
./selfhost/restore_sxc_full.sh
clang -O2 -o selfhost/sxc_full selfhost/sxc_full.c

if [ ! -x selfhost/gen1 ]; then
  echo "[bootstrap] pure compiler_min.sa -> gen1"
  ./selfhost/sxc_full selfhost/compiler_min.sa selfhost/gen1.c
  clang -O2 -o selfhost/gen1 selfhost/gen1.c
  cp selfhost/gen1.c selfhost/gen1_frozen.c
fi

run() {
  local src=$1 expect=$2 label=$3
  ./selfhost/gen1 "$src" selfhost/_out.c
  clang -O2 -o selfhost/_run selfhost/_out.c
  selfhost/_run | grep -q "$expect"
  echo "[OK] $label"
}

run selfhost/mini_in2.sa 42 "while/when/make"
./selfhost/sxc_full selfhost/mini_builtin.sa selfhost/_out.c
clang -O2 -o selfhost/_run selfhost/_out.c
selfhost/_run | grep -q done && echo "[OK] builtins (sxc_full)"
./selfhost/sxc_full selfhost/mini_index.sa selfhost/_out.c
clang -O2 -o selfhost/_run selfhost/_out.c
selfhost/_run | grep -q 72 && echo "[OK] indexing (sxc_full)"

echo "=== SUBSET-SELFHOST-OK ==="
