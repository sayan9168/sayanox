#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash selfhost/restore_stage2.sh
bash selfhost/sx selfhost/stage7_pipeline.sa
bash selfhost/sx selfhost/diagnostics.sa

PIPE="selfhost/stage2/stage7_pipeline"
DIAG="selfhost/stage2/diagnostics"

[ -x "$PIPE" ]
[ -x "$DIAG" ]

PIPE_OUTPUT="$($PIPE)"
DIAG_OUTPUT="$($DIAG)"

printf '%s\n' "$PIPE_OUTPUT"
printf '%s\n' "$DIAG_OUTPUT"

grep -q "Stage-7 pipeline contract OK" <<<"$PIPE_OUTPUT"
grep -q "Stage-7 diagnostics OK" <<<"$DIAG_OUTPUT"
grep -q "diagnostics" <<<"$DIAG_OUTPUT"

echo "Stage-7 self-host pipeline smoke test passed"
