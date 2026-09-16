#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash selfhost/restore_stage2.sh
bash selfhost/sx selfhost/stage24_real_functions.sa

BIN="selfhost/stage24_real_functions"
if [ ! -x "$BIN" ]; then
  echo "Stage-24 error: expected $BIN"
  exit 1
fi

OUTPUT="$($BIN)"
printf '%s\n' "$OUTPUT"
grep -q "Stage-24 real function pipeline OK" <<<"$OUTPUT"
grep -q "real function declaration parsed" <<<"$OUTPUT"
grep -q "real call discovered" <<<"$OUTPUT"
grep -q "signature linked" <<<"$OUTPUT"

echo "Stage-24 real function pipeline smoke test passed"
