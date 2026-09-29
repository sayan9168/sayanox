#!/usr/bin/env bash
# Thin wrapper — primary entry is the Makefile.
# Prefer:  make true-selfhost
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
exec make true-selfhost
