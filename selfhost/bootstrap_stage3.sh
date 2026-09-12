#!/usr/bin/env bash
# Stage-3 + CLI smoke test
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "=== Phase A: Stage-3 + CLI ==="
clang -o selfhost/stage2 selfhost/stage2_template.c 2>/dev/null || gcc -o selfhost/stage2 selfhost/stage2_template.c
chmod +x selfhost/sx

echo "[CLI] any path: hello.sa"
./selfhost/sx selfhost/hello.sa -o selfhost/cli_hello --run

echo "[CLI] struct_demo.sa"
./selfhost/sx selfhost/struct_demo.sa -o selfhost/cli_struct --run

echo "[Stage3] compiler_boot"
./selfhost/stage2 selfhost/compiler_boot.sa selfhost/stage3.c
clang -o selfhost/stage3 selfhost/stage3.c 2>/dev/null || gcc -o selfhost/stage3 selfhost/stage3.c
./selfhost/stage3
clang -o selfhost/hello_out selfhost/hello_out.c 2>/dev/null || gcc -o selfhost/hello_out selfhost/hello_out.c
echo -n "hello_out: "
./selfhost/hello_out
echo "=== Stage-3 + CLI OK ==="
