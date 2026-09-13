#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
cat selfhost/stage2_src/b64_0.txt selfhost/stage2_src/b64_1.txt selfhost/stage2_src/b64_2.txt selfhost/stage2_src/b64_3.txt | base64 -d > selfhost/stage2_template.c
echo "Decoded stage2_template.c ($(wc -c < selfhost/stage2_template.c) bytes)"
