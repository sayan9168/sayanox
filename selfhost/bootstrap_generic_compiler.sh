#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
echo "=== Generic compiler.sa ==="
clang -o selfhost/stage2 selfhost/stage2_template.c 2>/dev/null || gcc -o selfhost/stage2 selfhost/stage2_template.c
./selfhost/stage2 selfhost/compiler.sa selfhost/compiler_generic_out.c
clang -o selfhost/compiler_generic selfhost/compiler_generic_out.c 2>/dev/null || gcc -o selfhost/compiler_generic selfhost/compiler_generic_out.c
./selfhost/compiler_generic
clang -o selfhost/hello_out selfhost/hello_out.c 2>/dev/null || gcc -o selfhost/hello_out selfhost/hello_out.c
echo -n "hello: "
./selfhost/hello_out
echo "=== OK ==="
