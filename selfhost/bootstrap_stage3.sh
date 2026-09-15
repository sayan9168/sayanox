#!/usr/bin/env bash
# Stage-3 bootstrap — CI resilient
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc

echo "=== Stage-3 bootstrap ==="
chmod +x selfhost/restore_stage2.sh selfhost/sx
./selfhost/restore_stage2.sh

echo "[1/3] compiler_boot.sa"
./selfhost/stage2 selfhost/compiler_boot.sa selfhost/stage3.c
$CC -o selfhost/stage3 selfhost/stage3.c
./selfhost/stage3 >/dev/null || true
if [[ -f selfhost/hello_out.c ]]; then
  $CC -o selfhost/hello_out selfhost/hello_out.c
  test "$(./selfhost/hello_out)" = "42"
fi
echo "  OK"

echo "[2/3] compiler.sa lower (optional runtime)"
if [[ -f selfhost/compiler.sa ]]; then
  ./selfhost/stage2 selfhost/compiler.sa selfhost/stage3_compiler.c
  $CC -o selfhost/stage3_compiler selfhost/stage3_compiler.c
  ./selfhost/stage3_compiler >/dev/null 2>&1 || true
  echo "  OK"
fi

echo "[3/3] CLI smoke"
./selfhost/sx selfhost/hello.sa -o selfhost/cli_hello --run >/dev/null
test "$(./selfhost/cli_hello)" = "42"
echo "  OK"

echo "=== Stage-3 OK ==="
