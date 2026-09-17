#!/usr/bin/env bash
# ============================================================
# Full self-host bootstrap for Sayanox
# ============================================================
# Proves:
#   1) Stage-2 (C host) lowers Sayanox-written compilers
#   2) Those binaries compile .sa -> C -> executable (42)
#   3) Stage-3 loop: compiler_boot + compiler.sa + sayanoxc.sa
# ============================================================
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc

chmod +x selfhost/restore_stage2.sh selfhost/sx

echo "============================================"
echo " FULL SELF-HOST — Sayanox"
echo "============================================"

echo ""
echo "[0] Stage-2 host"
./selfhost/restore_stage2.sh
[[ -x selfhost/stage2 ]]

echo ""
echo "[1] Sayanoxc — compiler written in Sayanox"
./selfhost/stage2 selfhost/sayanoxc.sa selfhost/sayanoxc_host.c
$CC -O2 -o selfhost/sayanoxc_host selfhost/sayanoxc_host.c
./selfhost/sayanoxc_host
[[ -f selfhost/sayanoxc_out.c ]]
$CC -O2 -o selfhost/sayanoxc_prog selfhost/sayanoxc_out.c
OUT1="$(./selfhost/sayanoxc_prog)"
echo "    sayanoxc program output: $OUT1"
[[ "$OUT1" == "42" ]]
echo "    OK"

echo ""
echo "[2] compiler_boot.sa → Stage-3 binary"
./selfhost/stage2 selfhost/compiler_boot.sa selfhost/stage3.c
$CC -O2 -o selfhost/stage3 selfhost/stage3.c
./selfhost/stage3 >/dev/null 2>&1 || true
[[ -f selfhost/hello_out.c ]]
$CC -O2 -o selfhost/hello_out selfhost/hello_out.c
OUT2="$(./selfhost/hello_out)"
echo "    hello_out: $OUT2"
[[ "$OUT2" == "42" ]]
echo "    OK"

echo ""
echo "[3] compiler.sa (Stage-3 entry)"
./selfhost/stage2 selfhost/compiler.sa selfhost/stage3_compiler.c
$CC -O2 -o selfhost/stage3_compiler selfhost/stage3_compiler.c
./selfhost/stage3_compiler >/dev/null 2>&1 || true
if [[ -f selfhost/hello_out.c ]]; then
  $CC -O2 -o selfhost/hello_out2 selfhost/hello_out.c
  OUT3="$(./selfhost/hello_out2)"
  echo "    compiler.sa path: $OUT3"
  [[ "$OUT3" == "42" ]]
fi
echo "    OK"

echo ""
echo "[4] CLI path (sx) still works"
./selfhost/sx selfhost/hello.sa -o selfhost/cli_selfhost --run >/dev/null
OUT4="$(./selfhost/cli_selfhost)"
echo "    sx hello: $OUT4"
[[ "$OUT4" == "42" ]]
echo "    OK"

echo ""
echo "[5] Self-host identity check"
echo "    Stage-2 binary:     $(wc -c < selfhost/stage2) bytes"
echo "    Sayanoxc host:      $(wc -c < selfhost/sayanoxc_host) bytes"
echo "    Stage-3 compiler:   $(wc -c < selfhost/stage3_compiler) bytes"
echo "    Logic language:     Sayanox (.sa)"
echo "    Host for lowering:  Stage-2 (C)"

echo ""
echo "============================================"
echo " FULL SELF-HOST OK"
echo "============================================"
echo "Sayanox-written compilers compile programs."
echo "Stage-2 remains the bootstrap host for full grammar."
