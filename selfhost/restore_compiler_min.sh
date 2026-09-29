#!/usr/bin/env bash
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
# Prefer a complete checked-in compiler_min.sa (reassign version is ~15KB / 390+ lines)
if [ -f selfhost/compiler_min.sa ] && [ "$(wc -c < selfhost/compiler_min.sa)" -gt 10000 ]; then
  echo "keeping compiler_min.sa ($(wc -l < selfhost/compiler_min.sa) lines)"
  exit 0
fi
if [ -d selfhost/compiler_min_lines ]; then
  n=$(ls selfhost/compiler_min_lines/L*.txt 2>/dev/null | wc -l)
  if [ "$n" -ge 3 ]; then
    cat selfhost/compiler_min_lines/L*.txt > selfhost/compiler_min.sa
    echo "restored from lines ($(wc -c < selfhost/compiler_min.sa) bytes)"
    exit 0
  fi
fi
if [ -d selfhost/compiler_min_b64 ] && ls selfhost/compiler_min_b64/b*.txt >/dev/null 2>&1; then
  python3 - <<'PY'
import base64
from pathlib import Path
parts = sorted(Path("selfhost/compiler_min_b64").glob("b*.txt"))
b64 = "".join(p.read_text().strip() for p in parts)
raw = base64.b64decode(b64)
Path("selfhost/compiler_min.sa").write_bytes(raw)
print("restored compiler_min.sa", len(raw), "bytes")
PY
  exit 0
fi
if [ -f selfhost/compiler_min.sa ]; then
  echo "keeping existing compiler_min.sa ($(wc -l < selfhost/compiler_min.sa) lines)"
else
  echo "missing compiler_min.sa"; exit 1
fi
