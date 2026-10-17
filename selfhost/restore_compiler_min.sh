#!/bin/sh
# Restore selfhost/compiler_min.sa from the checked-in source, the legacy
# line parts, or the legacy base64 parts. POSIX sh only: no bash, no Python.
set -eu
cd "$(cd "$(dirname "$0")/.." && pwd)"
# Prefer a complete checked-in compiler_min.sa (the maintained case).
if [ -f selfhost/compiler_min.sa ] && [ "$(wc -c < selfhost/compiler_min.sa)" -gt 10000 ]; then
  echo "keeping compiler_min.sa ($(wc -l < selfhost/compiler_min.sa) lines)"
  exit 0
fi
if [ -d selfhost/compiler_min_lines ]; then
  n=$(ls selfhost/compiler_min_lines/L*.txt 2>/dev/null | wc -l)
  if [ "$n" -ge 3 ]; then
    cat selfhost/compiler_min_lines/L*.txt > selfhost/compiler_min.sa
    echo "restored from lines ($(wc -c < selfhost/compiler_min.sa) bytes)"
    exit 0
  fi
fi
if [ -d selfhost/compiler_min_b64 ]; then
  cat selfhost/compiler_min_b64/b*.txt 2>/dev/null | tr -d '\n' | base64 -d > selfhost/compiler_min.sa || true
  if [ -s selfhost/compiler_min.sa ]; then
    echo "restored compiler_min.sa $(wc -c < selfhost/compiler_min.sa) bytes"
    exit 0
  fi
  rm -f selfhost/compiler_min.sa
fi
if [ -f selfhost/compiler_min.sa ]; then
  echo "keeping existing compiler_min.sa ($(wc -l < selfhost/compiler_min.sa) lines)"
else
  echo "missing compiler_min.sa"; exit 1
fi
