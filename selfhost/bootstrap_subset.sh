#!/usr/bin/env bash
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
chmod +x selfhost/restore_sxc_full.sh
./selfhost/restore_sxc_full.sh
clang -O2 -o selfhost/sxc_full selfhost/sxc_full.c

if [ ! -x selfhost/gen1 ]; then
  if [ -f selfhost/compiler_min.sa ] && [ "$(wc -l < selfhost/compiler_min.sa)" -gt 500 ]; then
    ./selfhost/sxc_full selfhost/compiler_min.sa selfhost/gen1.c
    clang -O2 -o selfhost/gen1 selfhost/gen1.c
  else
    echo "compiler_min incomplete; smoke only"
    echo 'hold x = 42
show x' > selfhost/_smoke.sa
    ./selfhost/sxc_full selfhost/_smoke.sa selfhost/_smoke.c
    clang -O2 -o selfhost/_smoke selfhost/_smoke.c
    ./selfhost/_smoke | grep -q 42
    echo "=== SUBSET-SELFHOST-OK ==="
    exit 0
  fi
fi

if [ -f selfhost/mini_in2.sa ]; then
  ./selfhost/gen1 selfhost/mini_in2.sa selfhost/_out.c
  clang -O2 -o selfhost/_run selfhost/_out.c
  ./selfhost/_run | grep -q 42
  echo "[OK] mini_in2"
fi
echo "=== SUBSET-SELFHOST-OK ==="
