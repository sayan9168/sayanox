#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash selfhost/restore_stage2.sh
bash selfhost/sx selfhost/stage20_semantic.sa

BIN="selfhost/stage20_semantic"
if [ ! -x "$BIN" ]; then
  echo "Stage-20 error: expected $BIN"
  exit 1
fi

OUTPUT="$($BIN)"
printf '%s\n' "$OUTPUT"
grep -q "scope checked" <<<"$OUTPUT"
grep -q "types checked" <<<"$OUTPUT"
grep -q "Stage-20 semantic analyzer OK" <<<"$OUTPUT"

echo "Stage-20 semantic analyzer smoke test passed"
