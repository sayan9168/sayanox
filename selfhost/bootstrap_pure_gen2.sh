#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== TRUE PURE GEN2 ==="

# The only C seed is the canonical plain sxc_full.c. If the repository stores
# the same seed as plain text line parts, assemble it without decoding gzip/b64.
if [ ! -f selfhost/sxc_full.c ]; then
  if [ -d selfhost/sxc_full_lines ]; then
    cat selfhost/sxc_full_lines/L*.txt > selfhost/sxc_full.c
  else
    echo "error: missing selfhost/sxc_full.c and selfhost/sxc_full_lines/L*.txt" >&2
    exit 1
  fi
fi

test -s selfhost/sxc_full.c
grep -q 'sx_chr' selfhost/sxc_full.c
test ! -e selfhost/sxc_full_b64
test ! -e selfhost/sxc_full_b64.gz
test ! -e selfhost/gen1_frozen.c

echo "[1] Build canonical seed"
clang -O2 -o selfhost/sxc_full selfhost/sxc_full.c

echo "[2] Build gen1 from pure compiler_min.sa"
./selfhost/sxc_full selfhost/compiler_min.sa selfhost/gen1.c
clang -O2 -o selfhost/gen1 selfhost/gen1.c

echo "[3] Build gen2 from gen1 (no frozen copy)"
./selfhost/gen1 selfhost/compiler_min.sa selfhost/gen2.c
clang -O2 -o selfhost/gen2 selfhost/gen2.c

echo "[4] Compare gen1 and gen2 on mini_in2.sa"
./selfhost/gen1 selfhost/mini_in2.sa selfhost/gen1_mini.c
clang -O2 -o selfhost/gen1_mini selfhost/gen1_mini.c
./selfhost/gen1_mini > /tmp/sayanox-gen1.out

./selfhost/gen2 selfhost/mini_in2.sa selfhost/gen2_mini.c
clang -O2 -o selfhost/gen2_mini selfhost/gen2_mini.c
./selfhost/gen2_mini > /tmp/sayanox-gen2.out

diff -u /tmp/sayanox-gen1.out /tmp/sayanox-gen2.out
grep -Fxq "0" /tmp/sayanox-gen1.out
grep -Fxq "1" /tmp/sayanox-gen1.out
grep -Fxq "2" /tmp/sayanox-gen1.out
grep -Fxq "42" /tmp/sayanox-gen1.out
grep -Fxq "99" /tmp/sayanox-gen1.out
grep -Fxq "done" /tmp/sayanox-gen1.out

echo "=== TRUE-PURE-GEN2-OK ==="
