#!/usr/bin/env python3
"""Fix the Stage-2 generated ABI for the self-hosted keyword classifier."""
from pathlib import Path
import re

path = Path("selfhost/stage2_template.c")
src = path.read_text()

# The Stage-2 parser cannot infer parameter/return types in arbitrary user
# functions yet. `keyword` is a known compiler-internal string function.
src, count = re.subn(
    r"double sx_keyword\(double w\)",
    "char *sx_keyword(char *w)",
    src,
    count=1,
)
if count != 1:
    raise SystemExit("Expected generated sx_keyword signature was not found")

# String equality inside keyword() must use strcmp rather than C pointer
# equality. Keep the transformation narrowly scoped to that function.
start = src.find("char *sx_keyword(char *w)")
end = src.find("\n}", start)
if start < 0 or end < 0:
    raise SystemExit("Generated sx_keyword body was not found")
body = src[start:end]
body = re.sub(r"\(w == \"([A-Za-z]+)\"\)", r"(strcmp(w, \"\1\") == 0)", body)
body = re.sub(r"\(w != \"([A-Za-z]+)\"\)", r"(strcmp(w, \"\1\") != 0)", body)
src = src[:start] + body + src[end:]

path.write_text(src)
print("Patched Stage-2 keyword string ABI")
