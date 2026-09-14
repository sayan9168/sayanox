#!/usr/bin/env python3
import base64, gzip
from pathlib import Path
# Prefer split halves if present, else single gz.b64
a = Path("selfhost/codegen_a.b64")
b = Path("selfhost/codegen_b.b64")
if a.exists() and b.exists():
    blob = a.read_text().strip() + b.read_text().strip()
else:
    blob = Path("selfhost/codegen.sa.gz.b64").read_text().strip()
Path("selfhost/codegen.sa").write_bytes(gzip.decompress(base64.b64decode(blob)))
print("Wrote selfhost/codegen.sa", Path("selfhost/codegen.sa").stat().st_size)
