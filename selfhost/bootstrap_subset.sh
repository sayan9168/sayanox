#!/usr/bin/env bash
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
chmod +x selfhost/restore_sxc_full.sh
./selfhost/restore_sxc_full.sh
clang -O2 -o selfhost/sxc_full selfhost/sxc_full.c
if [ ! -x selfhost/gen1 ]; then
  ./selfhost/sxc_full selfhost/compiler_min.sa selfhost/gen1.c
  clang -O2 -o selfhost/gen1 selfhost/gen1.c
  cp selfhost/gen1.c selfhost/gen1_frozen.c
fi
./selfhost/gen1 selfhost/mini_in2.sa selfhost/_out.c
clang -O2 -o selfhost/_run selfhost/_out.c
./selfhost/_run | grep -q 42
echo "[OK] mini_in2"
./selfhost/sxc_full selfhost/mini_builtin.sa selfhost/_out.c
clang -O2 -o selfhost/_run selfhost/_out.c
./selfhost/_run | grep -q done
echo "[OK] builtins"
./selfhost/sxc_full selfhost/mini_index.sa selfhost/_out.c
clang -O2 -o selfhost/_run selfhost/_out.c
./selfhost/_run | grep -q 72
echo "[OK] index"
echo "=== SUBSET-SELFHOST-OK ==="
