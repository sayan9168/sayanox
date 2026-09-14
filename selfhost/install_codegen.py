#!/usr/bin/env python3
"""Install full Sayanox codegen.sa from compressed blob."""
import base64
import gzip
from pathlib import Path

b64 = Path("selfhost/codegen.sa.gz.b64").read_text().strip()
Path("selfhost/codegen.sa").write_bytes(gzip.decompress(base64.b64decode(b64)))
print("Wrote selfhost/codegen.sa", Path("selfhost/codegen.sa").stat().st_size, "bytes")
