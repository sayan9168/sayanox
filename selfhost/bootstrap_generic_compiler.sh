#!/usr/bin/env bash
# Generic lower of full compiler.sa (no semantic special-case)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Generic compiler.sa ==="
gcc -o selfhost/stage2 selfhost/stage2_template.c
./selfhost/stage2 selfhost/compiler.sa selfhost/compiler_generic_out.c
echo "[compile C]"
gcc -o selfhost/compiler_generic selfhost/compiler_generic_out.c
echo "[run]"
./selfhost/compiler_generic
gcc -o selfhost/hello_out selfhost/hello_out.c
echo -n "hello: "
./selfhost/hello_out
echo "=== OK ==="
