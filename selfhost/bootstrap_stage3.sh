#!/usr/bin/env bash
# Phase A: Stage-3 self-host loop
# Stage2 (C) generically compiles compiler_boot.sa -> stage3 binary
# Stage3 compiles hello.sa (via its own logic) without Rust
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Phase A: Stage-3 self-host loop ==="

echo "[1] Build Stage-2 from template"
gcc -o selfhost/stage2 selfhost/stage2_template.c

echo "[2] GENERIC lower compiler_boot.sa -> stage3.c"
./selfhost/stage2 selfhost/compiler_boot.sa selfhost/stage3.c

echo "[3] Link Stage-3 binary (no Rust)"
gcc -o selfhost/stage3 selfhost/stage3.c

echo "[4] Run Stage-3 (reads hello.sa, writes hello_out.c)"
./selfhost/stage3

echo "[5] Run generated program"
gcc -o selfhost/hello_out selfhost/hello_out.c
echo -n "  hello_out: "
./selfhost/hello_out

echo "=== Stage-3 loop OK (Rust not used in steps 2-5) ==="
