#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
chmod +x selfhost/restore_stage2.sh selfhost/sx selfhost/bootstrap_full_selfhost.sh
exec ./selfhost/bootstrap_full_selfhost.sh
