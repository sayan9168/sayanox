#!/usr/bin/env bash
# TRUE GEN1: seed compiles pure compiler_min.sa → gen1
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p selfhost/seed_tests

echo "=== TRUE GEN1 ==="
if [ -x selfhost/restore_compiler_min.sh ]; then
  chmod +x selfhost/restore_compiler_min.sh
  ./selfhost/restore_compiler_min.sh || true
fi
python3 selfhost/seed/apply_seed_fixes.py
clang -O2 -o selfhost/seed/sxc_seed selfhost/seed/sxc_seed.c -I selfhost/seed

echo "[1] seed: compiler_min.sa -> gen1.c"
./selfhost/seed/sxc_seed selfhost/compiler_min.sa > selfhost/gen1.c
test -s selfhost/gen1.c
grep -q sx_boot selfhost/gen1.c

echo "[2] clang: gen1.c -> gen1"
clang -O2 -o selfhost/gen1 selfhost/gen1.c -I selfhost/seed

echo "[3] reassign"
cat > selfhost/seed_tests/g1_re.sa << 'SA'
hold n = 0
hold n = 1
hold n = 2
show n
SA
./selfhost/gen1 selfhost/seed_tests/g1_re.sa selfhost/seed_tests/g1_re.c
clang -O2 -o selfhost/seed_tests/g1_re selfhost/seed_tests/g1_re.c
out=$(./selfhost/seed_tests/g1_re)
echo "$out" | grep -qx 2
echo "[OK] reassign"

echo "[4] multi-hold + string"
cat > selfhost/seed_tests/g1_str.sa << 'SA'
hold a = 10
hold b = 20
show a
show b
show "hi"
SA
./selfhost/gen1 selfhost/seed_tests/g1_str.sa selfhost/seed_tests/g1_str.c
clang -O2 -o selfhost/seed_tests/g1_str selfhost/seed_tests/g1_str.c
out=$(./selfhost/seed_tests/g1_str)
echo "$out" | grep -q 10
echo "$out" | grep -q 20
echo "$out" | grep -q hi
echo "[OK] multi-hold + string"

echo "[5] mini_in"
if [ -f selfhost/mini_in.sa ]; then
  ./selfhost/gen1 selfhost/mini_in.sa selfhost/seed_tests/g1_mini.c
  clang -O2 -o selfhost/seed_tests/g1_mini selfhost/seed_tests/g1_mini.c
  ./selfhost/seed_tests/g1_mini | grep -q 42
  echo "[OK] mini_in"
fi

if grep -q 'decls' selfhost/compiler_min.sa 2>/dev/null; then
  echo "[OK] pure min has reassign tracking"
fi

grep -q "sx_b_concat\|sx_b_read_file" selfhost/gen1.c
echo "[OK] gen1.c is seed-emitted (not frozen)"

echo "=== GEN1-OK ==="
