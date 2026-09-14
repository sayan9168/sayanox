#!/usr/bin/env python3
import base64
from pathlib import Path
a = Path("selfhost/codegen_a.b64").read_text().strip()
b = Path("selfhost/codegen_b.b64").read_text().strip()
Path("selfhost/codegen.sa").write_bytes(base64.b64decode(a + b))
print("Wrote codegen.sa", Path("selfhost/codegen.sa").stat().st_size)
