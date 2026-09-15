#!/usr/bin/env bash
# Stage-5 semantic verification. No Rust or Python is required here.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc

chmod +x selfhost/restore_stage2.sh
./selfhost/restore_stage2.sh

rm -f selfhost/stage5_semantic.c selfhost/stage5_semantic
./selfhost/stage2 selfhost/semantic.sa selfhost/stage5_semantic.c
$CC -O2 -o selfhost/stage5_semantic selfhost/stage5_semantic.c

./selfhost/stage5_semantic
