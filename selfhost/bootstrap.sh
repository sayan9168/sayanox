#!/usr/bin/env bash
# Sayanox bootstrap loop (Stage 0 = Rust binary)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Sayanox bootstrap ==="
echo "Stage 0: build Rust compiler if needed"
if [[ ! -x target/release/sayanox ]]; then
  cargo build --release
fi

echo "Stage 0 -> Stage 1: compile selfhost/compiler.sa to C"
./target/release/sayanox selfhost/compiler.sa -o selfhost/stage1.c

echo "Stage 1: gcc stage1.c"
gcc selfhost/stage1.c -o selfhost/stage1

echo "Stage 1: run (reads hello.sa, writes hello_out.c)"
./selfhost/stage1

echo "Stage 1 output program:"
gcc selfhost/hello_out.c -o selfhost/hello_out
./selfhost/hello_out

echo "=== Bootstrap demo complete ==="
echo "Note: full self-host (stage1 compiling compiler.sa) needs a complete"
echo "Sayanox-written compiler binary; Stage 1 currently targets hello.sa."
