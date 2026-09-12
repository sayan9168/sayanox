#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Sayanox bootstrap + generic Stage-2 ==="

if [[ ! -x target/release/sayanox ]]; then
  cargo build --release
fi

echo "[Stage 0]"
./target/release/sayanox selfhost/compiler.sa -o selfhost/stage1.c
gcc selfhost/stage1.c -o selfhost/stage1

echo "[Stage 1]"
./selfhost/stage1
gcc -o selfhost/hello_out selfhost/hello_out.c
echo -n "  hello_out: "; ./selfhost/hello_out

echo "[Stage 2 build]"
gcc -o selfhost/stage2 selfhost/stage2_cc.c

echo "[Stage 2] generic: hello.sa"
./selfhost/stage2 selfhost/hello.sa selfhost/stage2_out.c
gcc -o selfhost/stage2_out selfhost/stage2_out.c
echo -n "  result: "; ./selfhost/stage2_out

if [[ -f selfhost/generic_demo.sa ]]; then
  echo "[Stage 2] generic: generic_demo.sa"
  ./selfhost/stage2 selfhost/generic_demo.sa selfhost/generic_out.c
  gcc -o selfhost/generic_out selfhost/generic_out.c
  echo "  generic_out:"
  ./selfhost/generic_out
fi

echo "[Stage 2] semantic: compiler.sa"
./selfhost/stage2 selfhost/compiler.sa selfhost/compiler_stage2_out.c
gcc -o selfhost/compiler_from_stage2 selfhost/compiler_stage2_out.c
./selfhost/compiler_from_stage2
gcc -o selfhost/hello_from_sem selfhost/hello_out.c
echo -n "  hello from semantic: "; ./selfhost/hello_from_sem

echo "=== ALL OK ==="
