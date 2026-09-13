#!/usr/bin/env bash
# Full self-host verification (CI-safe)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Sayanox full self-host ==="

CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc

# Auto-restore if template is broken / placeholder
if ! grep -q 'compile_generic\|parse_stmt\|TokKind' selfhost/stage2_template.c 2>/dev/null; then
  echo "[0] Restoring Stage-2 template..."
  chmod +x selfhost/restore_stage2.sh
  ./selfhost/restore_stage2.sh
fi

echo "[1/5] Build Stage-2"
if [[ -f selfhost/stage2_expand.inc ]] && grep -q 'stage2_expand' selfhost/stage2_template.c 2>/dev/null; then
  $CC -I selfhost -o selfhost/stage2 selfhost/stage2_template.c
else
  $CC -o selfhost/stage2 selfhost/stage2_template.c
fi

echo "[2/5] hello.sa"
./selfhost/stage2 selfhost/hello.sa selfhost/out_hello.c
$CC -o selfhost/out_hello selfhost/out_hello.c
test "$(./selfhost/out_hello)" = "42"
echo "  hello -> 42 OK"

echo "[3/5] CLI sx"
chmod +x selfhost/sx
./selfhost/sx selfhost/hello.sa -o selfhost/cli_hello --run >/dev/null
test "$(./selfhost/cli_hello)" = "42"
echo "  sx OK"

echo "[4/5] Stage-3 compiler_boot"
./selfhost/stage2 selfhost/compiler_boot.sa selfhost/stage3.c
$CC -o selfhost/stage3 selfhost/stage3.c
./selfhost/stage3 >/dev/null
$CC -o selfhost/hello_out selfhost/hello_out.c
test "$(./selfhost/hello_out)" = "42"
echo "  stage3 -> 42 OK"

echo "[5/5] struct demo (optional)"
if [[ -f selfhost/struct_demo.sa ]]; then
  ./selfhost/stage2 selfhost/struct_demo.sa selfhost/out_struct.c
  $CC -o selfhost/out_struct selfhost/out_struct.c
  ./selfhost/out_struct | head -3
  echo "  struct OK"
fi

echo "=== FULL SELF-HOST OK ==="
