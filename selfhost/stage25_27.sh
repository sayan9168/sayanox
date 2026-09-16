#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash selfhost/restore_stage2.sh

run_stage() {
  local source="$1"
  local binary="${source%.sa}"
  bash selfhost/sx "$source"
  if [ ! -x "$binary" ]; then
    echo "Stage smoke error: expected $binary"
    exit 1
  fi
  local output
  output="$($binary)"
  printf '%s\n' "$output"
  grep -q "OK" <<<"$output"
}

run_stage selfhost/stage25_function_ast.sa
run_stage selfhost/stage26_function_body_ast.sa
run_stage selfhost/stage27_scopes.sa

echo "Stage-25/26/27 smoke tests passed"
