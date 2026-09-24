#!/usr/bin/env bash
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
chmod +x selfhost/bootstrap_subset.sh selfhost/bootstrap_pure_gen2.sh
./selfhost/bootstrap_subset.sh
./selfhost/bootstrap_pure_gen2.sh
echo "=== TRUE-SELF-COMPILE-OK ==="
