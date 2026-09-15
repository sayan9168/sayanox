#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
bash selfhost/restore_stage2.sh
bash selfhost/sx selfhost/stage15_checked_pipeline.sa
BIN="selfhost/stage15_checked_pipeline"
[ -x "$BIN" ]
OUTPUT="$($BIN)"
printf '%s\n' "$OUTPUT"
grep -q "AST arena materialized" <<<"$OUTPUT"
grep -q "binary expression checked" <<<"$OUTPUT"
grep -q "name resolution checked" <<<"$OUTPUT"
grep -q "Stage-15 semantic checks OK" <<<"$OUTPUT"
echo "Stage-15 checked pipeline smoke test passed"
