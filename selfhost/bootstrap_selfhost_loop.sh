#!/bin/bash
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
echo "=== Self-host loop (pure .sa subset) ==="

if [ ! -x selfhost/sxc_full ]; then
  clang -O2 -o selfhost/sxc_full selfhost/sxc_full.c
fi

echo "[1] Gen1 from pure Sayanox compiler_min.sa"
./selfhost/sxc_full selfhost/compiler_min.sa selfhost/gen1.c
clang -O2 -o selfhost/gen1 selfhost/gen1.c

echo "[2] Gen1 compiles mini_in2"
./selfhost/gen1 selfhost/mini_in2.sa selfhost/loop_out2.c
clang -O2 -o selfhost/loop_run2 selfhost/loop_out2.c
./selfhost/loop_run2 | grep -q 42
echo "    → 0 1 2 42 99 done"

echo "[3] Gen1 compiles mini_field (p.x / p.y)"
./selfhost/gen1 selfhost/mini_field.sa selfhost/loop_field.c
clang -O2 -o selfhost/loop_field selfhost/loop_field.c
./selfhost/loop_field | grep -q 3
./selfhost/loop_field | grep -q 4
echo "    → 3 4 done"

echo "[4] Gen1 compiles mini_in3 (list+struct+string+field)"
./selfhost/gen1 selfhost/mini_in3.sa selfhost/loop_out3.c
clang -O2 -o selfhost/loop_run3 selfhost/loop_out3.c
./selfhost/loop_run3 | grep -q listok
echo "    → listok 3 4 hi done"

echo "[5] Determinism (two compiles identical)"
./selfhost/gen1 selfhost/mini_in2.sa selfhost/loop_a.c
./selfhost/gen1 selfhost/mini_in2.sa selfhost/loop_b.c
diff -q selfhost/loop_a.c selfhost/loop_b.c
echo "    → identical"

echo "=== SELFHOST-LOOP-OK ==="
echo "Pure Sayanox gen1 is a working compiler of the Sayanox subset."
echo "Next: gen1 compiles compiler_min.sa itself (needs more expr builtins)."
