#!/usr/bin/env bash
# Full self-host verification (CI-safe)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Sayanox full self-host ==="

CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc

chmod +x selfhost/restore_stage2.sh selfhost/sx 2>/dev/null || true

echo "[1/5] Complete Stage-2 template + build"
./selfhost/restore_stage2.sh

echo "[2/5] hello.sa"
./selfhost/stage2 selfhost/hello.sa selfhost/out_hello.c
$CC -o selfhost/out_hello selfhost/out_hello.c
test "$(./selfhost/out_hello)" = "42"
echo "  hello -> 42 OK"

echo "[3/5] CLI sx"
./selfhost/sx selfhost/hello.sa -o selfhost/cli_hello --run >/dev/null
test "$(./selfhost/cli_hello)" = "42"
echo "  sx OK"

echo "[4/5] use modules"
./selfhost/stage2 selfhost/modules/main.sa selfhost/out_mod.c
$CC -o selfhost/out_mod selfhost/out_mod.c
test "$(./selfhost/out_mod)" = "42"
echo "  use module OK"

echo "[5/5] Stage-3 compiler_boot"
./selfhost/stage2 selfhost/compiler_boot.sa selfhost/stage3.c
$CC -o selfhost/stage3 selfhost/stage3.c
./selfhost/stage3 >/dev/null
$CC -o selfhost/hello_out selfhost/hello_out.c
test "$(./selfhost/hello_out)" = "42"
echo "  stage3 -> 42 OK"

echo "=== STAGE-2 COMPLETE + SELF-HOST OK ==="
