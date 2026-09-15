#!/usr/bin/env bash
# Stage-2 build — zero Python dependency
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TEMPLATE="selfhost/stage2_template.c"
DIR="selfhost/stage2_blob"

if [[ -d "$DIR" ]] && ls "$DIR"/chunk_* >/dev/null 2>&1; then
  echo "Assembling Stage-2 template (no Python)..."
  cat "$DIR"/chunk_* > /tmp/sx_stage2.b64
  base64 -d < /tmp/sx_stage2.b64 | gzip -d > "$TEMPLATE"
  rm -f /tmp/sx_stage2.b64
elif [[ -f selfhost/stage2_template.c.gz.b64 ]]; then
  echo "Decoding Stage-2 template..."
  base64 -d < selfhost/stage2_template.c.gz.b64 | gzip -d > "$TEMPLATE" || true
elif [[ ! -f "$TEMPLATE" ]]; then
  echo "error: no Stage-2 template sources" >&2
  exit 1
fi

echo "Building Stage-2..."
CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc
$CC -O2 -o selfhost/stage2 "$TEMPLATE"
echo "Stage-2 complete and compiled OK"
