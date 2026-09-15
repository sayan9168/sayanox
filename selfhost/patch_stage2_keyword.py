#!/usr/bin/env python3
"""Optional: harden Stage-2 sx_keyword if present."""
from pathlib import Path
import re
import sys

path = Path("selfhost/stage2_template.c")
src = path.read_text()

src2, count = re.subn(
    r"double sx_keyword\(double w\)",
    "char *sx_keyword(char *w)",
    src,
    count=1,
)
if count == 0 and "char *sx_keyword(char *w)" not in src2:
    print("patch_stage2_keyword: sx_keyword not found — skip")
    sys.exit(0)

src = src2
start = src.find("char *sx_keyword(char *w)")
if start < 0:
    print("patch_stage2_keyword: typed sx_keyword not found — skip")
    sys.exit(0)

depth = 0
end = -1
brace = src.find("{", start)
for index in range(brace, len(src)):
    if src[index] == "{":
        depth += 1
    elif src[index] == "}":
        depth -= 1
        if depth == 0:
            end = index
            break
if end < 0:
    print("patch_stage2_keyword: unclosed body — skip")
    sys.exit(0)

body = src[start : end + 1]
body2 = re.sub(r"\(w\s*==\s*\"([A-Za-z]+)\"\)", r'(strcmp(w, "\1") == 0)', body)
src = src[:start] + body2 + src[end + 1 :]
path.write_text(src)
print("Patched Stage-2 keyword comparisons")
