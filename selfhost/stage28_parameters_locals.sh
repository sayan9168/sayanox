#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash selfhost/restore_stage2.sh
bash selfhost/sx selfhost/stage28_parameters_locals.sa

BIN="selfhost/stage28_parameters_locals"
if [ ! -x "$BIN" ]; then
  echo "Stage-28 error: expected $BIN"
  exit 1
fi

OUTPUT="$($BIN)"
printf '%s\n' "$OUTPUT"
grep -q "Stage-28 parameters and locals OK" <<<"$OUTPUT"
grep -q "parameters bound" <<<"$OUTPUT"
grep -q "local variables bound" <<<"$OUTPUT"
grep -q "parameter/local resolution OK" <<<"$OUTPUT"

echo "Stage-28 parameters and locals smoke test passed"
