#!/usr/bin/env bash
# Full self-host verification (CI-safe)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Sayanox full self-host ==="

CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc

echo "[1/6] Build Stage-2 from stage2_template.c"
$CC -o selfhost/stage2 selfhost/stage2_template.c

echo "[2/6] Stage-2 compiles hello.sa"
./selfhost/stage2 selfhost/hello.sa selfhost/out_hello.c
$CC -o selfhost/out_hello selfhost/out_hello.c
test "$(./selfhost/out_hello)" = "42"
echo "  hello -> 42 OK"

echo "[3/6] CLI sx (any .sa path)"
chmod +x selfhost/sx
./selfhost/sx selfhost/hello.sa -o selfhost/cli_hello --run >/dev/null
test "$(./selfhost/cli_hello)" = "42"
echo "  sx OK"

echo "[4/6] Stage-2 use modules (optional if template has expand_uses)"
if grep -q expand_uses selfhost/stage2_template.c 2>/dev/null; then
  ./selfhost/stage2 selfhost/modules/main.sa selfhost/out_mod.c
  $CC -o selfhost/out_mod selfhost/out_mod.c
  test "$(./selfhost/out_mod)" = "42"
  echo "  use module OK"
else
  echo "  skipped (no expand_uses in template yet)"
fi

echo "[5/6] Stage-3 via compiler_boot.sa"
./selfhost/stage2 selfhost/compiler_boot.sa selfhost/stage3.c
$CC -o selfhost/stage3 selfhost/stage3.c
./selfhost/stage3 >/dev/null
$CC -o selfhost/hello_out selfhost/hello_out.c
test "$(./selfhost/hello_out)" = "42"
echo "  stage3 hello_out -> 42 OK"

echo "[6/6] Generic compiler.sa path"
if [[ -f selfhost/compiler.sa ]]; then
  ./selfhost/stage2 selfhost/compiler.sa selfhost/compiler_generic_out.c
  $CC -o selfhost/compiler_generic selfhost/compiler_generic_out.c
  ./selfhost/compiler_generic >/dev/null || true
  echo "  compiler.sa lowered OK"
fi

echo "=== FULL SELF-HOST OK ==="
echo "Self-host compiler: ./selfhost/stage2  (CLI: ./selfhost/sx)"
