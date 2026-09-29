#!/usr/bin/env bash
# TRUE GEN1: seed compiles pure compiler_min.sa → gen1 (hold/reassign/while/when)
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

echo "[4] while + n = n + 1"
cat > selfhost/seed_tests/g1_wh.sa << 'SA'
hold n = 0
while n < 3 {
  show n
  hold n = n + 1
}
show "done"
SA
./selfhost/gen1 selfhost/seed_tests/g1_wh.sa selfhost/seed_tests/g1_wh.c
clang -O2 -o selfhost/seed_tests/g1_wh selfhost/seed_tests/g1_wh.c
out=$(./selfhost/seed_tests/g1_wh)
echo "$out" | grep -q done
echo "$out" | grep -q 0
echo "$out" | grep -q 1
echo "$out" | grep -q 2
echo "[OK] while"

echo "[5] when"
cat > selfhost/seed_tests/g1_wn.sa << 'SA'
hold x = 2
when x == 1 {
  show 11
}
show 99
show "done"
SA
./selfhost/gen1 selfhost/seed_tests/g1_wn.sa selfhost/seed_tests/g1_wn.c
clang -O2 -o selfhost/seed_tests/g1_wn selfhost/seed_tests/g1_wn.c
out=$(./selfhost/seed_tests/g1_wn)
echo "$out" | grep -q 99
echo "$out" | grep -q done
if echo "$out" | grep -q '^11$'; then echo "FAIL: when body ran"; exit 1; fi
echo "[OK] when"

echo "[6] mini_in"
if [ -f selfhost/mini_in.sa ]; then
  ./selfhost/gen1 selfhost/mini_in.sa selfhost/seed_tests/g1_mini.c
  clang -O2 -o selfhost/seed_tests/g1_mini selfhost/seed_tests/g1_mini.c
  ./selfhost/seed_tests/g1_mini | grep -q 42
  echo "[OK] mini_in"
fi

grep -q "sx_b_concat\|sx_b_read_file" selfhost/gen1.c
echo "[OK] gen1.c is seed-emitted (not frozen)"

echo "=== GEN1-OK ==="
