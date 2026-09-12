#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
echo "=== Phase A: Stage-3 ==="
clang -o selfhost/stage2 selfhost/stage2_template.c 2>/dev/null || gcc -o selfhost/stage2 selfhost/stage2_template.c
./selfhost/stage2 selfhost/compiler_boot.sa selfhost/stage3.c
clang -o selfhost/stage3 selfhost/stage3.c 2>/dev/null || gcc -o selfhost/stage3 selfhost/stage3.c
./selfhost/stage3
clang -o selfhost/hello_out selfhost/hello_out.c 2>/dev/null || gcc -o selfhost/hello_out selfhost/hello_out.c
echo -n "hello_out: "
./selfhost/hello_out
echo "=== Stage-3 OK ==="
