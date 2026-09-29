#!/usr/bin/env bash
# TRUE FULL SELF-HOST: seed → gen1 → gen1 compiles compiler_min.sa → gen2 → tests
# Happy path dependencies: bash + a C compiler (clang/gcc/cc). No Python.
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
echo "Using CC=$CC (no Python required)"

# ---- bake seed fixes in-place with sed (replaces apply_seed_fixes.py) ----
SEED=selfhost/seed/sxc_seed.c
RT=selfhost/seed/sx_runtime.h
# P1 macro: avoid stringizing char literal
if grep -q 'ptok(k,(const char*)#ch' "$SEED" 2>/dev/null; then
  sed -i 's/ptok(k,(const char\*)#ch,0,sl,sc);/{ char _b[2]={(char)(ch),0}; ptok(k,_b,0,sl,sc);}/' "$SEED" 2>/dev/null || \
    sed -i '' 's/ptok(k,(const char\*)#ch,0,sl,sc);/{ char _b[2]={(char)(ch),0}; ptok(k,_b,0,sl,sc);}/' "$SEED"
fi
# stdarg include in emitted prologue
if grep -q 'sx_runtime.h\\"\\n\\n' "$SEED" 2>/dev/null; then
  sed -i 's/sx_runtime.h\\"\\n\\n/sx_runtime.h\\"\\n#include <stdarg.h>\\n\\n/' "$SEED" 2>/dev/null || \
    sed -i '' 's/sx_runtime.h\\"\\n\\n/sx_runtime.h\\"\\n#include <stdarg.h>\\n\\n/' "$SEED"
fi
# string header via offsetof
if grep -q 'sizeof(SxStrHdr)' "$RT" 2>/dev/null; then
  sed -i 's/(char\*)p-sizeof(SxStrHdr)/(char*)p-offsetof(SxStrHdr,data)/g' "$RT" 2>/dev/null || \
    sed -i '' 's/(char\*)p-sizeof(SxStrHdr)/(char*)p-offsetof(SxStrHdr,data)/g' "$RT"
  sed -i 's/malloc(sizeof(\*h)+n+1)/malloc(offsetof(SxStrHdr,data)+n+1)/g' "$RT" 2>/dev/null || \
    sed -i '' 's/malloc(sizeof(\*h)+n+1)/malloc(offsetof(SxStrHdr,data)+n+1)/g' "$RT"
fi
if ! grep -q '#include <stddef.h>' "$RT" 2>/dev/null; then
  sed -i 's/#include <stdint.h>/#include <stdint.h>\n#include <stddef.h>/' "$RT" 2>/dev/null || \
    sed -i '' 's/#include <stdint.h>/#include <stdint.h>\
#include <stddef.h>/' "$RT"
fi
if grep -q 'SX_TAB_CAP 262144' "$RT" 2>/dev/null; then
  sed -i 's/SX_TAB_CAP 262144/SX_TAB_CAP 2097152/' "$RT" 2>/dev/null || \
    sed -i '' 's/SX_TAB_CAP 262144/SX_TAB_CAP 2097152/' "$RT"
fi

# Restore fixed compiler_min.sa from gzip+b64 parts (shell only: base64 + gzip)
if [ -f selfhost/compiler_min.sa.gz.b64.p0 ]; then
  if [ ! -s selfhost/compiler_min.sa ] || ! grep -q 'decls_c' selfhost/compiler_min.sa 2>/dev/null; then
    echo "Restoring compiler_min.sa from parts (base64+gzip)..."
    cat selfhost/compiler_min.sa.gz.b64.p* | tr -d '\n' | base64 -d | gzip -d > selfhost/compiler_min.sa
  fi
fi
test -s selfhost/compiler_min.sa
grep -q 'decls_c' selfhost/compiler_min.sa

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
test -f selfhost/gen2.c && test -f selfhost/gen1.c
if cmp -s selfhost/gen1.c selfhost/gen2.c; then
  echo "[FAIL] gen2.c identical to gen1.c (frozen copy)"; exit 1
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
echo "Deps: C seed + bash + CC only (base64/gzip for optional parts restore)."
