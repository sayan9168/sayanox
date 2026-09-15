#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash selfhost/restore_stage2.sh
bash selfhost/sx selfhost/ir_pipeline.sa

BIN="selfhost/ir_pipeline"
if [ ! -x "$BIN" ]; then
  echo "Stage-11 error: expected $BIN"
  exit 1
fi

OUTPUT="$($BIN)"
printf '%s\n' "$OUTPUT"

grep -q "Stage-11 IR pipeline OK" <<<"$OUTPUT"
grep -q "basic blocks" <<<"$OUTPUT"
grep -q "temporaries" <<<"$OUTPUT"
grep -q "checks" <<<"$OUTPUT"

echo "Stage-11 IR pipeline smoke test passed"
