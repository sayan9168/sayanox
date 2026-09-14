#!/usr/bin/env bash
# Sayanox Stage-4 self-hosted toolchain smoke test.
# The orchestration layer is shell + Sayanox + C only; Rust is not required.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc

if [[ ! -x selfhost/stage2 ]]; then
  ./selfhost/restore_stage2.sh
fi

printf '%s\n' '=== Sayanox Stage-4 Self-Hosted Toolchain ==='

# Bootstrap the Stage-3 compiler from Sayanox source.
./selfhost/stage2 selfhost/compiler.sa selfhost/stage3_compiler.c
$CC -o selfhost/stage3_compiler selfhost/stage3_compiler.c

# The Stage-3 compiler consumes the canonical input file and emits C.
./selfhost/stage3_compiler >/dev/null

test -s selfhost/stage3_generated.c
$CC -o selfhost/stage4_output selfhost/stage3_generated.c

test "$(./selfhost/stage4_output)" = "42"

printf '%s\n' 'Stage-4 toolchain output: 42'
printf '%s\n' 'Rust host compiler is not part of this execution chain.'
printf '%s\n' '=== Stage-4 Self-Hosted Toolchain OK ==='
