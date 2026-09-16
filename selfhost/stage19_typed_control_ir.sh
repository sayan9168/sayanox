#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash selfhost/restore_stage2.sh
bash selfhost/sx selfhost/stage19_typed_control_ir.sa

BIN="selfhost/stage19_typed_control_ir"
if [ ! -x "$BIN" ]; then
  echo "Stage-19 error: expected $BIN"
  exit 1
fi

OUTPUT="$($BIN)"
printf '%s\n' "$OUTPUT"
grep -q "typed IR materialized" <<<"$OUTPUT"
grep -q "control-flow blocks validated" <<<"$OUTPUT"
grep -q "Stage-19 typed control IR OK" <<<"$OUTPUT"

echo "Stage-19 typed control IR smoke test passed"
