#!/usr/bin/env bash
# Canonical Step-1 bootstrap cycle.
# Stage-2 is the temporary bootstrap seed. The compiler logic under selfhost/
# is written in Sayanox and produces the next backend artifact.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CC=clang
command -v clang >/dev/null 2>&1 || CC=gcc

required_files=(
  selfhost/lexer.sa
  selfhost/parser.sa
  selfhost/ast.sa
  selfhost/semantic.sa
  selfhost/checked_ast.sa
  selfhost/ir.sa
  selfhost/lowering.sa
  selfhost/ir_builder.sa
  selfhost/backend_c.sa
  selfhost/compiler.sa
  selfhost/sayanoxc.sa
)

for file in "${required_files[@]}"; do
  [[ -f "$file" ]] || { echo "bootstrap: missing required stage: $file" >&2; exit 1; }
done

chmod +x selfhost/restore_stage2.sh
./selfhost/restore_stage2.sh
[[ -x selfhost/stage2 ]] || { echo "bootstrap: Stage-2 build failed" >&2; exit 1; }

echo "[1/4] Stage-2 -> Sayanox compiler host"
./selfhost/stage2 selfhost/compiler.sa selfhost/bootstrap_compiler.c
$CC -O2 -o selfhost/bootstrap_compiler selfhost/bootstrap_compiler.c

# compiler.sa consumes the configured target and emits the backend C artifact.
printf '%s' "selfhost/hello.sa" > selfhost/SX_TARGET
./selfhost/bootstrap_compiler >/dev/null 2>&1 || true
[[ -f selfhost/hello_out.c ]] || { echo "bootstrap: compiler did not emit hello_out.c" >&2; exit 1; }

echo "[2/4] Generated backend -> executable"
$CC -O2 -o selfhost/bootstrap_program selfhost/hello_out.c
output="$(./selfhost/bootstrap_program)"
echo "output: $output"
[[ "$output" == "42" ]] || { echo "bootstrap: expected 42" >&2; exit 1; }

echo "[3/4] Sayanox CLI regression"
chmod +x selfhost/sx
./selfhost/sx examples/hello.sa -o selfhost/bootstrap_cli --run >/dev/null
[[ "$(./selfhost/bootstrap_cli)" == "42" ]] || { echo "bootstrap: CLI regression failed" >&2; exit 1; }

echo "[4/4] Bootstrap cycle complete"
echo "SELFHOST STEP-1 OK"
echo "Temporary host: Stage-2 C seed"
echo "Compiler logic: Sayanox (.sa)"
echo "Next removal target: bootstrap C seed after native backend exists"
