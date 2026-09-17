#!/bin/sh
# Production bootstrap: one Stage-2 build, then Sayanox codegen path
set -e
cd "$(dirname "$0")/.." || exit 1
echo "=== Production bootstrap ==="
chmod +x selfhost/restore_stage2.sh 2>/dev/null || true
./selfhost/restore_stage2.sh
echo -n 'selfhost/multi_demo.sa' > selfhost/SX_TARGET
./selfhost/stage2 selfhost/codegen.sa selfhost/codegen_host.c
clang -O2 -o selfhost/codegen_host selfhost/codegen_host.c
./selfhost/codegen_host >/dev/null
clang -O2 -o selfhost/multi_out selfhost/codegen_emit.c
out="$(./selfhost/multi_out)"
echo "$out"
echo "$out" | grep -q 10
echo "$out" | grep -q 32
echo "=== PRODUCTION OK (Sayanox codegen multi-var) ==="
echo "Note: clang + Stage-2 C host still required to lower .sa once."
