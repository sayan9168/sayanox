#!/usr/bin/env bash
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"

echo "=== PURE EMIT ==="
test -f selfhost/sxc_full.c || { echo "need sxc_full.c"; exit 1; }
clang -O2 -o selfhost/sxc_full selfhost/sxc_full.c
clang -O2 -o selfhost/fixup_emit selfhost/fixup_emit.c

./selfhost/sxc_full selfhost/mini_index.sa selfhost/_ix.c
clang -O2 -o selfhost/_run selfhost/_ix.c
./selfhost/_run | grep -q 72
./selfhost/_run | grep -q 105
echo "[OK] index via sxc_full"

./selfhost/sxc_full selfhost/mini_reassign.sa selfhost/_re.c
clang -O2 -o selfhost/_run selfhost/_re.c
./selfhost/_run | grep -q 2
echo "[OK] reassign via sxc_full"

./selfhost/sxc_full selfhost/compiler_min.sa selfhost/gen1.c
clang -O2 -o selfhost/gen1 selfhost/gen1.c
./selfhost/gen1 selfhost/mini_in2.sa selfhost/_m2.c
clang -O2 -o selfhost/_run selfhost/_m2.c
./selfhost/_run | grep -q 42
echo "[OK] mini_in2 via gen1"

./selfhost/gen1 selfhost/mini_reassign.sa selfhost/_re_raw.c
./selfhost/fixup_emit selfhost/_re_raw.c selfhost/_re2.c
clang -O2 -o selfhost/_run selfhost/_re2.c
./selfhost/_run | grep -q 2
echo "[OK] reassign via gen1+fixup_emit"

echo "=== PURE-EMIT-OK ==="
echo "Note: string indexing still needs pure-min scanner work; sxc_full path is correct."
