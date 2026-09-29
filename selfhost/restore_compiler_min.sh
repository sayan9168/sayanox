#!/usr/bin/env bash
set -euo pipefail
cd "$(cd "$(dirname "$0")/.." && pwd)"
python3 - <<'PY'
import gzip, base64
from pathlib import Path
parts = sorted(Path("selfhost/compiler_min_parts").glob("p*.b64"))
b64 = "".join(p.read_text().strip() for p in parts)
raw = gzip.decompress(base64.b64decode(b64))
Path("selfhost/compiler_min.sa").write_bytes(raw)
print("restored compiler_min.sa", len(raw), "bytes")
PY
