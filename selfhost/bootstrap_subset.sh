#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -x selfhost/gen1 ]; then
  echo "[subset] using existing gen1"
else
  echo "[bootstrap] gen1 is missing; bootstrapping once"
  if [ ! -x selfhost/stage2 ]; then
    if [ -f selfhost/build_stage2.c ]; then
      echo "[bootstrap] building the C seed stage2 with clang"
      clang -O2 -o selfhost/build_stage2 selfhost/build_stage2.c
      ./selfhost/build_stage2
    fi
  fi
  if [ -x selfhost/stage2 ]; then
    echo "[bootstrap] stage2 -> gen1"
    ./selfhost/stage2 selfhost/compiler_min.sa selfhost/gen1.c
    clang -O2 -o selfhost/gen1 selfhost/gen1.c
  elif [ -f selfhost/sxc_full.c ]; then
    echo "[bootstrap] falling back to sxc_full.c"
    clang -O2 -o selfhost/sxc_full selfhost/sxc_full.c
    ./selfhost/sxc_full selfhost/compiler_min.sa selfhost/gen1.c
    clang -O2 -o selfhost/gen1 selfhost/gen1.c
  else
    echo "error: no existing gen1 and no C bootstrap seed is available" >&2
    exit 1
  fi
fi

echo "[subset] gen1 -> mini_in2"
./selfhost/gen1 selfhost/mini_in2.sa selfhost/_out.c
clang -O2 -o selfhost/_run selfhost/_out.c
./selfhost/_run | grep -q 42

echo "[subset] gen1 -> mini_field"
./selfhost/gen1 selfhost/mini_field.sa selfhost/_field.c
clang -O2 -o selfhost/_field selfhost/_field.c
./selfhost/_field | grep -q 3
./selfhost/_field | grep -q 4

echo "[subset] gen1 -> mini_builtin"
./selfhost/gen1 selfhost/mini_builtin.sa selfhost/_builtin.c
clang -O2 -o selfhost/_builtin selfhost/_builtin.c
./selfhost/_builtin | grep -q done

echo "[subset] gen1 -> mini_index"
./selfhost/gen1 selfhost/mini_index.sa selfhost/_index.c
clang -O2 -o selfhost/_index selfhost/_index.c
./selfhost/_index | grep -q 72

echo "[subset] gen1 -> mini_in3"
./selfhost/gen1 selfhost/mini_in3.sa selfhost/_in3.c
clang -O2 -o selfhost/_in3 selfhost/_in3.c
./selfhost/_in3 | grep -q listok

echo "=== SUBSET-SELFHOST-OK ==="
