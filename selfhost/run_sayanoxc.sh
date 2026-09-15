#!/usr/bin/env bash
# Build and run the Sayanox-written compiler
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
chmod +x selfhost/restore_stage2.sh selfhost/sx
[[ -x selfhost/stage2 ]] || ./selfhost/restore_stage2.sh

echo "=== Run sayanoxc.sa (compiler in Sayanox) ==="
./selfhost/sx selfhost/sayanoxc.sa --run

if [[ -f selfhost/sayanoxc_out.c ]]; then
  CC=clang; command -v clang >/dev/null 2>&1 || CC=gcc
  $CC -o selfhost/sayanoxc_out selfhost/sayanoxc_out.c
  echo "=== Output of compiled program ==="
  ./selfhost/sayanoxc_out
fi
