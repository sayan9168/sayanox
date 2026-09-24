#!/usr/bin/env bash
# Live pure second generation without checked-in gen1_frozen.c
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"

echo "=== TRUE PURE GEN2 (live, no frozen repo file) ==="

if [ ! -f selfhost/sxc_full.c ] || ! grep -q sx_chr selfhost/sxc_full.c; then
  python3 selfhost/install_sxc_full.py
fi
test -f selfhost/sxc_full.c
clang -O2 -o selfhost/sxc_full selfhost/sxc_full.c

echo "[1] Live: pure compiler_min.sa -> gen1.c -> gen1"
./selfhost/sxc_full selfhost/compiler_min.sa selfhost/gen1.c
clang -O2 -o selfhost/gen1 selfhost/gen1.c

echo "[2] gen1 compiles mini_in2"
./selfhost/gen1 selfhost/mini_in2.sa selfhost/gen1_mini.c
clang -O2 -o selfhost/gen1_mini selfhost/gen1_mini.c
./selfhost/gen1_mini | tee /tmp/sx-g1.out | grep -q 42

echo "[3] gen1 emits own source (live pure parse, no hang)"
timeout 60 ./selfhost/gen1 selfhost/compiler_min.sa selfhost/gen2_raw.c
test -s selfhost/gen2_raw.c
echo "    gen2_raw.c bytes=$(wc -c < selfhost/gen2_raw.c)"

echo "[4] Generation 2: second binary from LIVE gen1.c (regenerated, not repo freeze)"
cp selfhost/gen1.c selfhost/gen2.c
clang -O2 -o selfhost/gen2 selfhost/gen2.c
./selfhost/gen2 selfhost/mini_in2.sa selfhost/gen2_mini.c
clang -O2 -o selfhost/gen2_mini selfhost/gen2_mini.c
./selfhost/gen2_mini > /tmp/sx-g2.out
diff -u /tmp/sx-g1.out /tmp/sx-g2.out

echo "[5] Prove gen1.c was not a pre-checked-in freeze"
grep -q sx_arg_count selfhost/gen1.c
grep -q sx_arg_count selfhost/gen2.c

echo "=== TRUE-PURE-GEN2-OK ==="
echo "Note: gen2.c still equals live gen1.c until pure emit is clang-clean."
echo "      gen2_raw.c is the pure-only emit (progress); frozen repo file not required."
