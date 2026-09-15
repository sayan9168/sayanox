#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash selfhost/restore_stage2.sh
bash selfhost/sx selfhost/source_ir.sa

BIN="selfhost/source_ir"
if [ ! -x "$BIN" ]; then
  echo "Stage-13 error: expected $BIN"
  exit 1
fi

OUTPUT="$($BIN)"
printf '%s\n' "$OUTPUT"
grep -q "Stage-13 source-to-IR OK" <<<"$OUTPUT"
grep -q "IR instructions" <<<"$OUTPUT"
grep -q "6" <<<"$OUTPUT"

echo "Stage-13 source-to-IR smoke test passed"
