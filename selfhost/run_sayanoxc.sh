#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
chmod +x selfhost/restore_stage2.sh selfhost/sx
[[ -x selfhost/stage2 ]] || ./selfhost/restore_stage2.sh

echo "=== Sayanoxc (compiler written in Sayanox) ==="
./selfhost/sx selfhost/sayanoxc.sa --run

if [[ -f selfhost/sayanoxc_out.c ]]; then
  CC=clang; command -v clang >/dev/null 2>&1 || CC=gcc
  $CC -o selfhost/sayanoxc_out selfhost/sayanoxc_out.c
  echo "=== compiled program output ==="
  ./selfhost/sayanoxc_out
fi
