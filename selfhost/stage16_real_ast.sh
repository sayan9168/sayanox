#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash selfhost/restore_stage2.sh
bash selfhost/sx selfhost/stage16_real_ast.sa

BIN="selfhost/stage16_real_ast"
if [ ! -x "$BIN" ]; then
  echo "Stage-16 error: expected $BIN"
  exit 1
fi

OUTPUT="$($BIN)"
printf '%s\n' "$OUTPUT"
grep -q "source parsed" <<<"$OUTPUT"
grep -q "real AST materialized" <<<"$OUTPUT"
grep -q "Stage-16 real AST OK" <<<"$OUTPUT"

echo "Stage-16 real parser-to-AST smoke test passed"
