#!/usr/bin/env python3
"""Restore full true-selfhost compiler_min.sa from gzip+base64 if present."""
from pathlib import Path
import base64, gzip, sys

here = Path(__file__).resolve().parent
out = here / "compiler_min.sa"
blob = here / "compiler_min.sa.gz.b64"
if blob.is_file():
    raw = gzip.decompress(base64.b64decode(blob.read_text().strip()))
    out.write_bytes(raw)
    print("restored compiler_min.sa", len(raw), "bytes from", blob.name)
    sys.exit(0)
b64dir = here / "compiler_min_b64"
if b64dir.is_dir() and list(b64dir.glob("b*.txt")):
    parts = sorted(b64dir.glob("b*.txt"))
    raw = base64.b64decode("".join(p.read_text().strip() for p in parts))
    out.write_bytes(raw)
    print("restored compiler_min.sa", len(raw), "bytes from b64 parts")
    sys.exit(0)
print("apply_selfhost_fixes: keeping existing", out, out.stat().st_size if out.exists() else 0)
