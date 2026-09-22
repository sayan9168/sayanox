#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if [ -f selfhost/sxc_full.c ] && grep -q sx_chr selfhost/sxc_full.c; then
  echo "sxc_full.c OK ($(wc -c < selfhost/sxc_full.c) bytes)"
  exit 0
fi
if [ -d selfhost/sxc_full_lines ]; then
  cat selfhost/sxc_full_lines/L*.txt > selfhost/sxc_full.c
  grep -q sx_chr selfhost/sxc_full.c
  echo "restored from line parts ($(wc -c < selfhost/sxc_full.c) bytes)"
  exit 0
fi
echo "error: missing sxc_full.c" >&2
exit 1
