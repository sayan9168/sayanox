#!/usr/bin/env python3
import base64, gzip
from pathlib import Path
parts = []
for name in ["codegen_a.b64", "codegen_b.b64", "codegen_c.b64", "codegen_d.b64"]:
    p = Path("selfhost") / name
    if p.exists():
        parts.append(p.read_text().strip())
if len(parts) == 4:
    blob = "".join(parts)
else:
    blob = Path("selfhost/codegen.sa.gz.b64").read_text().strip()
Path("selfhost/codegen.sa").write_bytes(gzip.decompress(base64.b64decode(blob)))
print("Wrote selfhost/codegen.sa", Path("selfhost/codegen.sa").stat().st_size)
