#!/usr/bin/env bash
# Stage-2 build — zero Python dependency
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TEMPLATE="selfhost/stage2_template.c"
BLOB="selfhost/stage2_template.c.gz.b64"

if [[ -f "$BLOB" ]]; then
  echo "Decoding committed Stage-2 template (no Python)..."
  base64 -d < "$BLOB" | gzip -d > "$TEMPLATE"
elif [[ ! -f "$TEMPLATE" ]]; then
  echo "error: missing $TEMPLATE and $BLOB" >&2
  exit 1
fi

echo "Building Stage-2..."
CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc
$CC -O2 -o selfhost/stage2 "$TEMPLATE"
echo "Stage-2 complete and compiled OK"
