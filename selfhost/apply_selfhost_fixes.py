#!/usr/bin/env python3
from pathlib import Path
import base64, gzip, sys
here = Path(__file__).resolve().parent
out = here / "compiler_min.sa"
parts = sorted(here.glob("compiler_min.sa.gz.b64.p*"))
if parts:
    b64 = "".join(p.read_text().strip() for p in parts)
    raw = gzip.decompress(base64.b64decode(b64))
    out.write_bytes(raw)
    print("restored compiler_min.sa", len(raw), "bytes from", len(parts), "parts")
    sys.exit(0)
print("keeping existing compiler_min.sa")
