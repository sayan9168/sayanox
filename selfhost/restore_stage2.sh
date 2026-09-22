#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ -f selfhost/stage2_template.c ] &&    ! grep -q 'PLACEHOLDER' selfhost/stage2_template.c &&    grep -q 'sx_chr\|compile_generic\|TokKind' selfhost/stage2_template.c; then
  clang -O2 -o selfhost/stage2 selfhost/stage2_template.c
  echo "stage2_template.c OK"
  exit 0
fi

if [ -f selfhost/sxc_full.c ] && grep -q sx_chr selfhost/sxc_full.c; then
  cp selfhost/sxc_full.c selfhost/stage2_template.c
  clang -O2 -o selfhost/stage2 selfhost/stage2_template.c
  echo "stage2 restored from plain sxc_full.c"
  exit 0
fi

if [ -f selfhost/stage2_src/01_front.c ] && [ -f selfhost/stage2_src/02_back.c ]; then
  cat selfhost/stage2_src/01_front.c selfhost/stage2_src/02_back.c > selfhost/stage2_template.c
  grep -q sx_chr selfhost/stage2_template.c
  clang -O2 -o selfhost/stage2 selfhost/stage2_template.c
  echo "stage2 restored from plain source parts"
  exit 0
fi

echo "error: missing Stage-2 seed; expected plain selfhost/sxc_full.c or selfhost/stage2_src/*.c" >&2
exit 1
