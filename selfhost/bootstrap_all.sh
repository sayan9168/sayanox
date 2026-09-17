#!/usr/bin/env bash
# Run all major smoke paths
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

chmod +x selfhost/restore_stage2.sh selfhost/sx selfhost/bootstrap_full_selfhost.sh \
  selfhost/bootstrap_full_language_selfhost.sh tools/sxpkg tools/sxfmt.sh tools/sayanox-lsp.sh \
  tools/sxrepl.sh 2>/dev/null || true

echo "======== [1/4] Stage-2 ========"
./selfhost/restore_stage2.sh
./selfhost/sx examples/hello.sa --run | tail -3
./selfhost/sx examples/greet.sa --run | tail -5

echo "======== [2/4] Full self-host ========"
./selfhost/bootstrap_full_selfhost.sh | tail -8

echo "======== [3/4] Full-language self-host ========"
./selfhost/bootstrap_full_language_selfhost.sh | tail -10

echo "======== [4/4] Tools ========"
./tools/sxfmt.sh examples/hello.sa | head -3
./tools/sxpkg init 2>/dev/null || true
./tools/sxpkg install || true
echo "LSP binary: tools/sayanox-lsp.sh"

echo "======== ALL SMOKE OK ========"
