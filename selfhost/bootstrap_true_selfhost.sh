#!/usr/bin/env bash
# TRUE FULL SELF-HOST: seed → gen1 → gen1 compiles compiler_min.sa → gen2 → tests
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p selfhost/seed_tests

CC="${CC:-}"
if [ -z "$CC" ]; then
  if command -v clang >/dev/null 2>&1; then CC=clang
  elif command -v gcc >/dev/null 2>&1; then CC=gcc
  else CC=cc
  fi
fi

echo "=== TRUE FULL SELF-HOST ==="
echo "Using CC=$CC"

python3 selfhost/seed/apply_seed_fixes.py || true
# ensure large object table for self-compile of compiler_min
if grep -q 'SX_TAB_CAP 262144' selfhost/seed/sx_runtime.h 2>/dev/null; then
  sed -i 's/SX_TAB_CAP 262144/SX_TAB_CAP 2097152/' selfhost/seed/sx_runtime.h 2>/dev/null || \
    sed -i '' 's/SX_TAB_CAP 262144/SX_TAB_CAP 2097152/' selfhost/seed/sx_runtime.h
fi

$CC -O2 -o selfhost/seed/sxc_seed selfhost/seed/sxc_seed.c -I selfhost/seed

echo "[1] seed: compiler_min.sa -> gen1.c"
./selfhost/seed/sxc_seed selfhost/compiler_min.sa > selfhost/gen1.c
test -s selfhost/gen1.c
$CC -O2 -o selfhost/gen1 selfhost/gen1.c -I selfhost/seed

echo "[2] gen1 compiles compiler_min.sa -> gen2.c (TRUE self-compile)"
./selfhost/gen1 selfhost/compiler_min.sa selfhost/gen2.c
test -s selfhost/gen2.c
grep -q 'int main' selfhost/gen2.c
$CC -O2 -o selfhost/gen2 selfhost/gen2.c

echo "[3] gen2 runs pure-min tests"
cat > selfhost/seed_tests/ts_re.sa << 'SA'
hold n = 0
hold n = 1
hold n = 2
show n
SA
./selfhost/gen2 selfhost/seed_tests/ts_re.sa selfhost/seed_tests/ts_re.c >/dev/null
$CC -O2 -o selfhost/seed_tests/ts_re selfhost/seed_tests/ts_re.c
out=$(./selfhost/seed_tests/ts_re)
echo "$out" | grep -qx 2
echo "[OK] gen2 reassign"

cat > selfhost/seed_tests/ts_wh.sa << 'SA'
hold n = 0
while n < 3 {
  show n
  hold n = n + 1
}
show "done"
SA
./selfhost/gen2 selfhost/seed_tests/ts_wh.sa selfhost/seed_tests/ts_wh.c >/dev/null
$CC -O2 -o selfhost/seed_tests/ts_wh selfhost/seed_tests/ts_wh.c
out=$(./selfhost/seed_tests/ts_wh)
echo "$out" | grep -q done
echo "$out" | grep -q 0
echo "$out" | grep -q 2
echo "[OK] gen2 while"

cat > selfhost/seed_tests/ts_wn.sa << 'SA'
hold x = 2
when x == 1 {
  show 11
}
show 99
SA
./selfhost/gen2 selfhost/seed_tests/ts_wn.sa selfhost/seed_tests/ts_wn.c >/dev/null
$CC -O2 -o selfhost/seed_tests/ts_wn selfhost/seed_tests/ts_wn.c
out=$(./selfhost/seed_tests/ts_wn)
echo "$out" | grep -q 99
if echo "$out" | grep -q '^11$'; then echo "FAIL when"; exit 1; fi
echo "[OK] gen2 when"

echo "[4] gen2 is not a frozen copy of gen1.c"
test -f selfhost/gen2.c
test -f selfhost/gen1.c
# must differ (self-compile produces different translation of the same source)
if cmp -s selfhost/gen1.c selfhost/gen2.c; then
  echo "[FAIL] gen2.c identical to gen1.c (frozen copy)"
  exit 1
fi
echo "[OK] gen2.c differs from gen1.c (live self-compile)"

echo "[5] gen2 compiles compiler_boot.sa (third generation path)"
./selfhost/gen2 selfhost/compiler_boot.sa selfhost/boot_from_gen2.c >/dev/null
test -s selfhost/boot_from_gen2.c
$CC -O2 -o selfhost/boot_from_gen2 selfhost/boot_from_gen2.c
./selfhost/boot_from_gen2 selfhost/seed_tests/ts_re.sa selfhost/seed_tests/ts_re_b.c >/dev/null
$CC -O2 -o selfhost/seed_tests/ts_re_b selfhost/seed_tests/ts_re_b.c
out=$(./selfhost/seed_tests/ts_re_b)
echo "$out" | grep -qx 2
echo "[OK] boot_from_gen2 reassign"

echo "=== TRUE-FULL-SELFHOST-OK ==="
