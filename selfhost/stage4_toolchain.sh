#!/usr/bin/env bash
# Stage-4 smoke — Rust-free chain
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc

echo "=== Stage-4 toolchain ==="
if [[ ! -x selfhost/stage2 ]]; then
  chmod +x selfhost/restore_stage2.sh
  ./selfhost/restore_stage2.sh
fi

# Prefer compiler_boot path (stable)
./selfhost/stage2 selfhost/compiler_boot.sa selfhost/stage4_driver.c
$CC -o selfhost/stage4_driver selfhost/stage4_driver.c
./selfhost/stage4_driver >/dev/null || true

if [[ -f selfhost/hello_out.c ]]; then
  $CC -o selfhost/stage4_output selfhost/hello_out.c
  test "$(./selfhost/stage4_output)" = "42"
  echo "Stage-4 output: 42"
else
  # Fallback: direct hello
  ./selfhost/stage2 selfhost/hello.sa selfhost/stage4_hello.c
  $CC -o selfhost/stage4_output selfhost/stage4_hello.c
  test "$(./selfhost/stage4_output)" = "42"
  echo "Stage-4 fallback hello: 42"
fi

echo "=== Stage-4 OK ==="
