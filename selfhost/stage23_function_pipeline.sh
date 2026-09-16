#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash selfhost/restore_stage2.sh
bash selfhost/sx selfhost/stage23_function_pipeline.sa

BIN="selfhost/stage23_function_pipeline"
if [ ! -x "$BIN" ]; then
  echo "Stage-23 error: expected $BIN"
  exit 1
fi

OUTPUT="$($BIN)"
printf '%s\n' "$OUTPUT"
grep -q "function AST resolved" <<<"$OUTPUT"
grep -q "call lowered to typed IR" <<<"$OUTPUT"
grep -q "Stage-23 function pipeline OK" <<<"$OUTPUT"

echo "Stage-23 function pipeline smoke test passed"
