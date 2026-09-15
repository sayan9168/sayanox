#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash selfhost/restore_stage2.sh
bash selfhost/sx selfhost/checked_ast.sa

BIN="selfhost/checked_ast"
if [ ! -x "$BIN" ]; then
  echo "Stage-8 error: expected $BIN"
  exit 1
fi

OUTPUT="$($BIN)"
printf '%s\n' "$OUTPUT"

grep -q "Stage-8 checked AST OK" <<<"$OUTPUT"
grep -q "nodes" <<<"$OUTPUT"
grep -q "checks" <<<"$OUTPUT"

echo "Stage-8 checked AST smoke test passed"
