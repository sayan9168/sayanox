#!/usr/bin/env bash
# Restore + complete Stage-2 template (English, use expansion, modulo fix)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GOOD_URL="https://raw.githubusercontent.com/sayan9168/sayanox/bef338f0cc1344fa0167b64b827f2409dddb8200/selfhost/stage2_template.c"

echo "Downloading known-good Stage-2 base..."
curl -fsSL "$GOOD_URL" -o selfhost/stage2_template.c

python3 selfhost/complete_stage2.py
python3 selfhost/patch_stage2_strings.py
python3 selfhost/patch_stage2_string_compare.py
python3 selfhost/patch_stage2_keyword.py

echo "Verifying compile..."
CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc
$CC -o selfhost/stage2 selfhost/stage2_template.c
echo "Stage-2 complete and compiled OK"
