#!/usr/bin/env python3
"""Harden Stage-2 output for the self-hosted keyword classifier."""
from pathlib import Path
import re

path = Path("selfhost/stage2_template.c")
src = path.read_text()

# complete_stage2.py now emits the correct string ABI directly. Keep this
# patch idempotent for older generated templates and normalize either form.
src, count = re.subn(
    r"double sx_keyword\(double w\)",
    "char *sx_keyword(char *w)",
    src,
    count=1,
)
if count == 0 and "char *sx_keyword(char *w)" not in src:
    raise SystemExit("Generated sx_keyword function was not found")

start = src.find("char *sx_keyword(char *w)")
if start < 0:
    raise SystemExit("Typed sx_keyword function was not found")

# Find the matching closing brace instead of stopping at the first nested
# brace, then rewrite only string comparisons inside keyword().
depth = 0
end = -1
for index in range(src.find("{", start), len(src)):
    if src[index] == "{":
        depth += 1
    elif src[index] == "}":
        depth -= 1
        if depth == 0:
            end = index
            break
if end < 0:
    raise SystemExit("Generated sx_keyword body was not closed")

body = src[start:end]
body = re.sub(r"\(w\s*==\s*\"([A-Za-z]+)\"\)", r'(strcmp(w, "\1") == 0)', body)
body = re.sub(r"\(w\s*!=\s*\"([A-Za-z]+)\"\)", r'(strcmp(w, "\1") != 0)', body)
src = src[:start] + body + src[end:]

path.write_text(src)
print("Patched Stage-2 keyword string ABI")
