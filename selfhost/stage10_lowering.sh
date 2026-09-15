#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash selfhost/restore_stage2.sh
bash selfhost/sx selfhost/lowering.sa

BIN="selfhost/lowering"
if [ ! -x "$BIN" ]; then
  echo "Stage-10 error: expected $BIN"
  exit 1
fi

OUTPUT="$($BIN)"
printf '%s\n' "$OUTPUT"

grep -q "Stage-10 lowering OK" <<<"$OUTPUT"
grep -q "lowered" <<<"$OUTPUT"
grep -q "checks" <<<"$OUTPUT"

echo "Stage-10 lowering smoke test passed"
