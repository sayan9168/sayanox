#!/usr/bin/env bash
# Full-language self-host: Sayanox-written codegen compiles hold/show/when/while
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc

chmod +x selfhost/restore_stage2.sh selfhost/sx
echo "============================================"
echo " FULL-LANGUAGE SELF-HOST"
echo "============================================"

echo ""
echo "[0] Stage-2 host"
./selfhost/restore_stage2.sh

compile_target() {
  local target="$1"
  local label="$2"
  echo -n "$target" > selfhost/SX_TARGET
  ./selfhost/stage2 selfhost/codegen.sa selfhost/sayanoxc_full_host.c
  $CC -O2 -o selfhost/sayanoxc_full_host selfhost/sayanoxc_full_host.c 2>/dev/null
  ./selfhost/sayanoxc_full_host >/dev/null
  $CC -O2 -o selfhost/codegen_prog selfhost/codegen_emit.c
  local out
  out="$(./selfhost/codegen_prog)"
  echo "  [$label] $target -> $out"
  [[ "$out" == *"42"* ]] || { echo "FAIL $label"; exit 1; }
}

echo ""
echo "[1] Sayanox codegen.sa (hold/show/when/while)"
compile_target "selfhost/hello.sa" "hello"
compile_target "selfhost/hold_show.sa" "hold+show"
compile_target "selfhost/when_demo.sa" "when"
compile_target "selfhost/while_demo.sa" "while"
echo "  OK"

echo ""
echo "[2] Stage-2 full grammar smoke"
./selfhost/sx examples/hello.sa -o selfhost/fl_hello --run >/dev/null
[[ "$(./selfhost/fl_hello)" == "42" ]]
./selfhost/sx examples/greet.sa -o selfhost/fl_greet --run >/dev/null
./selfhost/fl_greet | grep -q Hello
./selfhost/sx examples/countdown.sa -o selfhost/fl_cd --run >/dev/null
[[ "$(./selfhost/fl_cd | tail -1)" == "done" ]]
echo "  OK"

echo ""
echo "[3] Identity"
echo "  Full-language host:     Stage-2 (C) for complete grammar"
echo "  Self-host compiler:     codegen.sa (Sayanox) hold/show/when/while"
echo "  Binary:                 selfhost/sayanoxc_full_host"

echo ""
echo "============================================"
echo " FULL-LANGUAGE SELF-HOST OK"
echo "============================================"
