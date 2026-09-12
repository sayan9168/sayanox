#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Sayanox bootstrap (semantic Stage 2) ==="

if [[ ! -x target/release/sayanox ]]; then
  cargo build --release
fi

echo "[Stage 0] compile compiler.sa"
./target/release/sayanox selfhost/compiler.sa -o selfhost/stage1.c
gcc selfhost/stage1.c -o selfhost/stage1

echo "[Stage 1] run"
./selfhost/stage1
gcc selfhost/hello_out.c -o selfhost/hello_out
echo -n "[Stage 1] hello_out: "
./selfhost/hello_out

echo "[Stage 2] build"
gcc selfhost/stage2_cc.c -o selfhost/stage2

echo "[Stage 2] compile hello.sa"
./selfhost/stage2 selfhost/hello.sa selfhost/stage2_out.c
gcc selfhost/stage2_out.c -o selfhost/stage2_out
echo -n "[Stage 2] stage2_out: "
./selfhost/stage2_out

echo "[Stage 2] FULL semantic compile of compiler.sa"
./selfhost/stage2 selfhost/compiler.sa selfhost/compiler_stage2_out.c
gcc selfhost/compiler_stage2_out.c -o selfhost/compiler_from_stage2

echo "[Stage 2] run compiler produced from compiler.sa"
./selfhost/compiler_from_stage2
gcc selfhost/hello_out.c -o selfhost/hello_from_sem
echo -n "[Stage 2] hello from semantic compiler: "
./selfhost/hello_from_sem

echo "=== SUCCESS: Stage 2 lowered compiler.sa to a working compiler binary ==="
