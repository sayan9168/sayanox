#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash selfhost/restore_stage2.sh
bash selfhost/sx selfhost/typeenv.sa

BIN="selfhost/stage2/typeenv"
if [ ! -x "$BIN" ]; then
  echo "Stage-6 error: expected $BIN"
  exit 1
fi

OUTPUT="$($BIN)"
printf '%s\n' "$OUTPUT"

grep -q "Stage-6 type environment OK" <<<"$OUTPUT"
grep -q "checks" <<<"$OUTPUT"
grep -q "bindings" <<<"$OUTPUT"

echo "Stage-6 type environment smoke test passed"
