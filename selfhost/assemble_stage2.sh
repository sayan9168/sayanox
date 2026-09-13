#!/usr/bin/env bash
# Assemble full Stage-2 template from parts
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
cat selfhost/stage2_src/01_front.c selfhost/stage2_src/02_back.c > selfhost/stage2_template.c
echo "Assembled selfhost/stage2_template.c ($(wc -c < selfhost/stage2_template.c) bytes)"
