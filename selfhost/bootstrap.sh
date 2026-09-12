#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Sayanox bootstrap Stage 0 / 1 / 2 ==="

if [[ ! -x target/release/sayanox ]]; then
  cargo build --release
fi

echo "[Stage 0] sayanox selfhost/compiler.sa -> stage1.c"
./target/release/sayanox selfhost/compiler.sa -o selfhost/stage1.c
gcc selfhost/stage1.c -o selfhost/stage1

echo "[Stage 1] run Sayanox-built stage1"
./selfhost/stage1

test -f selfhost/hello_out.c
test -f selfhost/stage2_cc.c

gcc selfhost/hello_out.c -o selfhost/hello_out
echo -n "[Stage 1] hello_out: "
./selfhost/hello_out

echo "[Stage 2] build mini compiler"
gcc selfhost/stage2_cc.c -o selfhost/stage2

echo "[Stage 2] compile hello.sa"
./selfhost/stage2 selfhost/hello.sa selfhost/stage2_out.c
gcc selfhost/stage2_out.c -o selfhost/stage2_out
echo -n "[Stage 2] stage2_out: "
./selfhost/stage2_out

echo "[Stage 2] compile compiler.sa (partial)"
./selfhost/stage2 selfhost/compiler.sa selfhost/compiler_stage2_out.c
gcc selfhost/compiler_stage2_out.c -o selfhost/compiler_stage2_out
echo "[Stage 2] compiler.sa partial output:"
./selfhost/compiler_stage2_out

echo "=== Bootstrap complete ==="
