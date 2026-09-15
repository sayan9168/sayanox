#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
bash selfhost/restore_stage2.sh
bash selfhost/sx selfhost/ir.sa
BIN="selfhost/ir"
if [ ! -x "$BIN" ]; then
  echo "Stage-9 error: expected $BIN"
  exit 1
fi
OUTPUT="$($BIN)"
printf '%s\n' "$OUTPUT"
grep -q "Stage-9 IR OK" <<<"$OUTPUT"
grep -q "IR instructions" <<<"$OUTPUT"
grep -q "IR checks" <<<"$OUTPUT"
echo "Stage-9 IR smoke test passed"
