#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash selfhost/restore_stage2.sh
bash selfhost/sx selfhost/stage18_native_backend.sa

BIN="selfhost/stage18_native_backend"
if [ ! -x "$BIN" ]; then
  echo "Stage-18 error: expected $BIN"
  exit 1
fi

OUTPUT="$($BIN)"
printf '%s\n' "$OUTPUT"
grep -q "Stage-18 native backend OK" <<<"$OUTPUT"

gcc -std=c11 -Wall -Wextra -Werror selfhost/stage18_generated.c -o selfhost/stage18_generated
NATIVE_OUTPUT="$(selfhost/stage18_generated)"
printf '%s\n' "$NATIVE_OUTPUT"
test "$NATIVE_OUTPUT" = "42"

echo "Stage-18 IR-to-native backend smoke test passed"
