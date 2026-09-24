#!/usr/bin/env bash
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
ok() { [ -f selfhost/sxc_full.c ] && grep -q sx_chr selfhost/sxc_full.c && [ "$(wc -c < selfhost/sxc_full.c)" -gt 10000 ]; }
if ok; then echo "sxc_full.c OK ($(wc -c < selfhost/sxc_full.c) bytes)"; exit 0; fi
if [ -d selfhost/sxc_full_lines ]; then
  cat selfhost/sxc_full_lines/L*.txt > selfhost/sxc_full.c || true
fi
if ! ok && [ -d selfhost/sxc_full_b64_plain ]; then
  cat selfhost/sxc_full_b64_plain/p*.txt | tr -d '\n' | base64 -d > selfhost/sxc_full.c
fi
if ! ok; then echo "error: cannot restore sxc_full.c" >&2; exit 1; fi
echo "restored sxc_full.c ($(wc -c < selfhost/sxc_full.c) bytes)"
