#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash selfhost/restore_stage2.sh
bash selfhost/sx selfhost/codegen.sa -o selfhost/codegen

TARGET_BACKUP="$(cat selfhost/SX_TARGET)"
restore_target() {
  printf '%s\n' "$TARGET_BACKUP" > selfhost/SX_TARGET
}
trap restore_target EXIT

CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc

run_case() {
  target="$1"
  binary="$2"
  expected="$3"
  printf '%s\n' "$target" > selfhost/SX_TARGET
  ./selfhost/codegen
  test -s selfhost/codegen_emit.c
  $CC -std=c11 -Wall -Wextra -Werror selfhost/codegen_emit.c -o "$binary"
  actual="$("./$binary")"
  test "$actual" = "$expected"
}

run_case selfhost/struct_codegen_demo.sa selfhost/struct_codegen_demo "3
4
7"
run_case selfhost/list_codegen_demo.sa selfhost/list_codegen_demo "2
3"

printf '%s\n' "$TARGET_BACKUP" > selfhost/SX_TARGET
printf '%s\n' "Sayanox struct/list codegen smoke test passed"
