#!/usr/bin/env bash
# Supported pure-gen2 entrypoint.
# Keep the public target on the live path so it never silently falls back to
# selfhost/gen1_frozen.c. The true script owns seed restoration, live gen1
# generation, and the TRUE-PURE-GEN2-OK marker.
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
exec ./selfhost/bootstrap_true_pure_gen2.sh
