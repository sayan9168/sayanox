#!/usr/bin/env bash
# Supported pure-gen2 entrypoint (kept for `make pure-gen2`).
#
# The real work lives in bootstrap_gen2.sh: seed -> gen1 -> boot -> boot2 with
# no copied generation.  This wrapper exists only so older callers and the
# Makefile keep working.
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
exec ./selfhost/bootstrap_gen2.sh
