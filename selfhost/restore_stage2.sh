#!/usr/bin/env bash
# Restore full Stage-2 template (English) from a known-good upstream revision
# and optionally inject use-file expansion.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GOOD_URL="https://raw.githubusercontent.com/sayan9168/sayanox/bef338f0cc1344fa0167b64b827f2409dddb8200/selfhost/stage2_template.c"

echo "Downloading known-good Stage-2 template..."
curl -fsSL "$GOOD_URL" -o selfhost/stage2_template.c

# Fix modulo snprintf if present (literal %%)
if grep -q '(%s)%(long)' selfhost/stage2_template.c; then
  sed -i 's/(%s)%(long)/(%s)%%(long)/g' selfhost/stage2_template.c || \
    sed -i '' 's/(%s)%(long)/(%s)%%(long)/g' selfhost/stage2_template.c
fi

# Ensure English one-line header note
if ! grep -q 'Self-host' selfhost/stage2_template.c; then
  printf '%s\n' '/* Sayanox Stage-2 - .sa to C (English). Self-host compiler. */' | cat - selfhost/stage2_template.c > selfhost/stage2_template.c.tmp
  mv selfhost/stage2_template.c.tmp selfhost/stage2_template.c
fi

echo "Restored selfhost/stage2_template.c ($(wc -c < selfhost/stage2_template.c) bytes)"
echo "Build with: clang -o selfhost/stage2 selfhost/stage2_template.c"
