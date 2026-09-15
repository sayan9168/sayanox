#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash selfhost/restore_stage2.sh
bash selfhost/sx selfhost/backend_c.sa

BIN="selfhost/backend_c"
if [ ! -x "$BIN" ]; then
  echo "Stage-12 error: expected $BIN"
  exit 1
fi

OUTPUT="$($BIN)"
printf '%s\n' "$OUTPUT"
grep -q "Stage-12 C backend OK" <<<"$OUTPUT"

gcc -std=c11 -Wall -Wextra -Werror selfhost/stage12_generated.c -o selfhost/stage12_generated
NATIVE_OUTPUT="$(selfhost/stage12_generated)"
printf '%s\n' "$NATIVE_OUTPUT"
test "$NATIVE_OUTPUT" = "42"

echo "Stage-12 end-to-end C backend smoke test passed"
