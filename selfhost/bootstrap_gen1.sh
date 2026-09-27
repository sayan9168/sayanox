#!/usr/bin/env bash
# TRUE GEN1: seed compiles pure compiler_min.sa → gen1 binary (no cp freeze)
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p selfhost/seed_tests

echo "=== TRUE GEN1 ==="
python3 selfhost/seed/apply_seed_fixes.py
clang -O2 -o selfhost/seed/sxc_seed selfhost/seed/sxc_seed.c -I selfhost/seed

echo "[1] seed: compiler_min.sa -> gen1.c"
./selfhost/seed/sxc_seed selfhost/compiler_min.sa > selfhost/gen1.c
test -s selfhost/gen1.c
grep -q sx_boot selfhost/gen1.c

echo "[2] clang: gen1.c -> gen1"
clang -O2 -o selfhost/gen1 selfhost/gen1.c -I selfhost/seed

echo "[3] gen1 compiles hold/show programs"
cat > selfhost/seed_tests/g1_hold.sa << 'SA'
hold a = 10
hold b = 20
show a
show b
SA
./selfhost/gen1 selfhost/seed_tests/g1_hold.sa selfhost/seed_tests/g1_hold.c
clang -O2 -o selfhost/seed_tests/g1_hold selfhost/seed_tests/g1_hold.c
out=$(./selfhost/seed_tests/g1_hold)
echo "$out" | grep -q 10
echo "$out" | grep -q 20
echo "[OK] multi-hold"

cat > selfhost/seed_tests/g1_str.sa << 'SA'
hold x = 42
show x
show "hi"
SA
./selfhost/gen1 selfhost/seed_tests/g1_str.sa selfhost/seed_tests/g1_str.c
clang -O2 -o selfhost/seed_tests/g1_str selfhost/seed_tests/g1_str.c
out=$(./selfhost/seed_tests/g1_str)
echo "$out" | grep -q 42
echo "$out" | grep -q hi
echo "[OK] string show"

if [ -f selfhost/mini_in.sa ]; then
  ./selfhost/gen1 selfhost/mini_in.sa selfhost/seed_tests/g1_mini.c
  clang -O2 -o selfhost/seed_tests/g1_mini selfhost/seed_tests/g1_mini.c
  ./selfhost/seed_tests/g1_mini | grep -q 42
  echo "[OK] mini_in.sa"
fi

test -f selfhost/gen1.c
grep -q "sx_b_concat\|sx_b_read_file\|sx_b_arg" selfhost/gen1.c
echo "[OK] gen1.c is seed-emitted pure-compiler (not frozen artifact)"

echo "=== GEN1-OK ==="
