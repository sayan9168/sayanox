#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
chmod +x selfhost/bootstrap_subset.sh selfhost/bootstrap_pure_gen2.sh
./selfhost/bootstrap_subset.sh
./selfhost/bootstrap_pure_gen2.sh
echo "=== TRUE-SELF-COMPILE-OK ==="
