#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash selfhost/restore_stage2.sh
bash selfhost/sx selfhost/stage14_parser_bridge.sa

BIN="selfhost/stage14_parser_bridge"
if [ ! -x "$BIN" ]; then
  echo "Stage-14 error: expected $BIN"
  exit 1
fi

OUTPUT="$($BIN)"
printf '%s\n' "$OUTPUT"
grep -q "source loaded" <<<"$OUTPUT"
grep -q "AST bridge built" <<<"$OUTPUT"
grep -q "Stage-14 parser bridge OK" <<<"$OUTPUT"

echo "Stage-14 parser bridge smoke test passed"
