#!/bin/sh
# Rebuild selfhost/stage2 from a plain C template or source parts.
# Deliberately exits 1 today: the Stage-2 host is not in this repository.
# POSIX sh only (no bash), matching the rest of the bootstrap scripts.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CC=${CC:-clang}
command -v "$CC" >/dev/null 2>&1 || CC=cc

if [ -f selfhost/stage2_template.c ] && \
   ! grep -q 'PLACEHOLDER' selfhost/stage2_template.c && \
   grep -qE 'sx_chr|compile_generic|TokKind' selfhost/stage2_template.c; then
  "$CC" -O2 -o selfhost/stage2 selfhost/stage2_template.c
  echo "stage2_template.c OK"
  exit 0
fi

if [ -f selfhost/sxc_full.c ] && grep -q sx_chr selfhost/sxc_full.c; then
  cp selfhost/sxc_full.c selfhost/stage2_template.c
  "$CC" -O2 -o selfhost/stage2 selfhost/stage2_template.c
  echo "stage2 restored from plain sxc_full.c"
  exit 0
fi

if [ -f selfhost/stage2_src/01_front.c ] && [ -f selfhost/stage2_src/02_back.c ]; then
  cat selfhost/stage2_src/01_front.c selfhost/stage2_src/02_back.c > selfhost/stage2_template.c
  grep -q sx_chr selfhost/stage2_template.c
  "$CC" -O2 -o selfhost/stage2 selfhost/stage2_template.c
  echo "stage2 restored from plain source parts"
  exit 0
fi

echo "error: missing Stage-2 seed; expected plain selfhost/sxc_full.c or selfhost/stage2_src/*.c" >&2
exit 1
