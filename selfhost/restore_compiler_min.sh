#!/usr/bin/env bash
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
if [ -d selfhost/compiler_min_lines ] && ls selfhost/compiler_min_lines/L*.txt >/dev/null 2>&1; then
  cat selfhost/compiler_min_lines/L*.txt > selfhost/compiler_min.sa
  echo "restored from lines ($(wc -c < selfhost/compiler_min.sa) bytes)"
elif [ -f selfhost/compiler_min.sa ]; then
  echo "keeping compiler_min.sa ($(wc -l < selfhost/compiler_min.sa) lines)"
else
  echo "missing compiler_min.sa"; exit 1
fi
