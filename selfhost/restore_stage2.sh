#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GOOD_URL="https://raw.githubusercontent.com/sayan9168/sayanox/bef338f0cc1344fa0167b64b827f2409dddb8200/selfhost/stage2_template.c"

echo "Downloading known-good Stage-2 base..."
curl -fsSL "$GOOD_URL" -o selfhost/stage2_template.c

python3 selfhost/complete_stage2.py
python3 selfhost/patch_stage2_strings.py || echo "warn: string patch skipped"
python3 selfhost/patch_stage2_string_compare.py || echo "warn: string-compare patch skipped"
python3 selfhost/patch_stage2_keyword.py || echo "warn: keyword patch skipped"
python3 selfhost/patch_stage2_rc.py || echo "warn: RC/arena patch skipped"
python3 selfhost/patch_stage2_strname.py || echo "warn: strname patch skipped"
python3 selfhost/patch_stage2_autodrop.py || echo "warn: autodrop patch skipped"

echo "Verifying compile..."
CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc
$CC -o selfhost/stage2 selfhost/stage2_template.c
echo "Stage-2 complete and compiled OK"
