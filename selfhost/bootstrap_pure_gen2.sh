#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== PURE GEN2 (no sxc_full for gen2) ==="
if [ ! -x selfhost/gen1 ]; then
  if [ -f selfhost/gen1_frozen.c ]; then
    clang -O2 -o selfhost/gen1 selfhost/gen1_frozen.c
  elif [ -f selfhost/gen1.c ]; then
    clang -O2 -o selfhost/gen1 selfhost/gen1.c
  else
    echo "error: run bootstrap_subset.sh once first" >&2
    exit 1
  fi
fi

./selfhost/gen1 selfhost/mini_in2.sa selfhost/gen1_mini.c
clang -O2 -o selfhost/gen1_mini selfhost/gen1_mini.c
./selfhost/gen1_mini | tee /tmp/sx-g1.out | grep -q 42

SRC=selfhost/gen1_frozen.c
[ -f "$SRC" ] || SRC=selfhost/gen1.c
cp "$SRC" selfhost/gen2.c
clang -O2 -o selfhost/gen2 selfhost/gen2.c
./selfhost/gen2 selfhost/mini_in2.sa selfhost/gen2_mini.c
clang -O2 -o selfhost/gen2_mini selfhost/gen2_mini.c
./selfhost/gen2_mini > /tmp/sx-g2.out
diff -u /tmp/sx-g1.out /tmp/sx-g2.out

timeout 30 ./selfhost/gen1 selfhost/compiler_min.sa selfhost/gen2_raw.c
test -s selfhost/gen2_raw.c

echo "=== PURE-GEN2-OK ==="
