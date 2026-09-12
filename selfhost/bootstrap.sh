#!/usr/bin/env bash
# Sayanox bootstrap — Stage 0 (Rust) builds Stage 1 (Sayanox-built binary)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Sayanox bootstrap ==="

if [[ ! -x target/release/sayanox ]]; then
  echo "[Stage 0] Building Rust bootstrap compiler..."
  cargo build --release
fi

echo "[Stage 0] Compiling selfhost/compiler.sa -> selfhost/stage1.c"
./target/release/sayanox selfhost/compiler.sa -o selfhost/stage1.c

echo "[Stage 0] Linking Stage-1 binary"
gcc selfhost/stage1.c -o selfhost/stage1

echo "[Stage 1] Running Sayanox-built compiler (reads hello.sa, writes hello_out.c)"
./selfhost/stage1

if [[ ! -f selfhost/hello_out.c ]]; then
  echo "ERROR: Stage 1 did not produce selfhost/hello_out.c"
  exit 1
fi

echo "[Stage 1] Compiling generated program"
gcc selfhost/hello_out.c -o selfhost/hello_out
echo -n "[Stage 1] Program output: "
./selfhost/hello_out

if [[ -f selfhost/stage1_ok.txt ]]; then
  echo "[Stage 1] Marker: $(cat selfhost/stage1_ok.txt)"
fi

echo ""
echo "=== Bootstrap summary ==="
echo "  Stage 0 binary : target/release/sayanox  (Rust)"
echo "  Stage 1 binary : selfhost/stage1         (built from Sayanox sources via C)"
echo "  Stage 1 compiled selfhost/hello.sa -> hello_out.c successfully"
echo ""
echo "  Full Stage 2 (stage1 compiling compiler.sa itself) still requires"
echo "  complete C lowering of the full self-host source language."
echo "=== done ==="
