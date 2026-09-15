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
  if ! base64 -d < /tmp/sx_stage2.b64 2>/dev/null | gzip -d > "$TEMPLATE" 2>/dev/null; then
    echo "warn: blob incomplete, trying curl base..." >&2
    curl -fsSL "https://raw.githubusercontent.com/sayan9168/sayanox/bef338f0cc1344fa0167b64b827f2409dddb8200/selfhost/stage2_template.c" -o "$TEMPLATE"
  fi
  rm -f /tmp/sx_stage2.b64
elif [[ ! -f "$TEMPLATE" ]]; then
  echo "Fetching Stage-2 base template..."
  curl -fsSL "https://raw.githubusercontent.com/sayan9168/sayanox/bef338f0cc1344fa0167b64b827f2409dddb8200/selfhost/stage2_template.c" -o "$TEMPLATE"
fi

echo "Building Stage-2..."
CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc
$CC -O2 -o selfhost/stage2 "$TEMPLATE"
echo "Stage-2 complete and compiled OK"
