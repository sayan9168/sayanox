#!/usr/bin/env bash
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
chmod +x selfhost/restore_sxc_full.sh
./selfhost/restore_sxc_full.sh
clang -O2 -o selfhost/sxc_full selfhost/sxc_full.c

# Smoke always works with minimal or full seed
echo 'hold x = 42
show x' > selfhost/_smoke.sa
./selfhost/sxc_full selfhost/_smoke.sa selfhost/_smoke.c
clang -O2 -o selfhost/_smoke selfhost/_smoke.c
./selfhost/_smoke | grep -q 42
echo "[OK] smoke 42"

# Full path only if full pure min present
if [ -f selfhost/compiler_min.sa ] && [ "$(wc -l < selfhost/compiler_min.sa)" -gt 500 ]; then
  if ! grep -q sx_chr selfhost/sxc_full.c; then
    echo "seed is minimal; skip full gen1"
  else
    ./selfhost/sxc_full selfhost/compiler_min.sa selfhost/gen1.c
    clang -O2 -o selfhost/gen1 selfhost/gen1.c
    if [ -f selfhost/mini_in2.sa ]; then
      ./selfhost/gen1 selfhost/mini_in2.sa selfhost/_out.c
      clang -O2 -o selfhost/_run selfhost/_out.c
      ./selfhost/_run | grep -q 42
      echo "[OK] mini_in2"
    fi
  fi
fi
echo "=== SUBSET-SELFHOST-OK ==="
