#!/bin/sh
# Restore stage2_template.c from gzip+base64 part
set -e
cd "$(dirname "$0")/.."
cat selfhost/stage2_template_parts/p00.b64 | tr -d '\n' | base64 -d | gzip -d > selfhost/stage2_template.c
echo "restored stage2_template.c ($(wc -c < selfhost/stage2_template.c) bytes)"
