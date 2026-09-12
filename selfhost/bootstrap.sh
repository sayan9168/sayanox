#!/usr/bin/env bash
# Sayanox bootstrap: Stage 0 (Rust) -> Stage 1 (Sayanox-built) -> Stage 2 (generated C mini-cc)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Sayanox bootstrap (Stage 0 / 1 / 2) ==="

if [[ ! -x target/release/sayanox ]]; then
  echo "[Stage 0] Building Rust bootstrap compiler..."
  cargo build --release
fi

echo "[Stage 0] Compiling selfhost/compiler.sa -> selfhost/stage1.c"
./target/release/sayanox selfhost/compiler.sa -o selfhost/stage1.c

echo "[Stage 0] Linking Stage-1 binary"
gcc selfhost/stage1.c -o selfhost/stage1

echo "[Stage 1] Running Sayanox-built compiler"
./selfhost/stage1

if [[ ! -f selfhost/hello_out.c ]]; then
  echo "ERROR: missing selfhost/hello_out.c"
  exit 1
fi
if [[ ! -f selfhost/stage2_cc.c ]]; then
  echo "ERROR: missing selfhost/stage2_cc.c (Stage-2 source)"
  exit 1
fi

echo "[Stage 1] Building program from hello_out.c"
gcc selfhost/hello_out.c -o selfhost/hello_out
echo -n "[Stage 1] hello_out runs: "
./selfhost/hello_out

echo "[Stage 2] Linking Stage-2 mini compiler from Stage-1 output"
gcc selfhost/stage2_cc.c -o selfhost/stage2

echo "[Stage 2] Running Stage-2 compiler on selfhost/hello.sa"
./selfhost/stage2

if [[ ! -f selfhost/stage2_out.c ]]; then
  echo "ERROR: Stage 2 did not produce selfhost/stage2_out.c"
  exit 1
fi

echo "[Stage 2] Building and running Stage-2 output program"
gcc selfhost/stage2_out.c -o selfhost/stage2_out
echo -n "[Stage 2] stage2_out runs: "
./selfhost/stage2_out

echo ""
echo "=== Bootstrap complete ==="
echo "  Stage 0 : target/release/sayanox     (Rust)"
echo "  Stage 1 : selfhost/stage1            (from compiler.sa via Sayanox)"
echo "  Stage 2 : selfhost/stage2            (C mini-cc emitted by Stage 1)"
echo "  Stage 2 compiled selfhost/hello.sa -> stage2_out.c successfully"
echo "=== done ==="
