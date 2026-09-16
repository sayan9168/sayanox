#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash selfhost/restore_stage2.sh
bash selfhost/sx selfhost/stage22_functions.sa

BIN="selfhost/stage22_functions"
if [ ! -x "$BIN" ]; then
  echo "Stage-22 error: expected $BIN"
  exit 1
fi

OUTPUT="$($BIN)"
printf '%s\n' "$OUTPUT"
grep -q "Stage-22 function checker OK" <<<"$OUTPUT"
grep -q "function signature resolved" <<<"$OUTPUT"
grep -q "parameters checked" <<<"$OUTPUT"
grep -q "return type checked" <<<"$OUTPUT"

echo "Stage-22 function checker smoke test passed"
