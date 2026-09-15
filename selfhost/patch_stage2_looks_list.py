#!/usr/bin/env python3
"""looks_list: treat list variable names as lists (alias support)."""
from pathlib import Path
import re
import sys

path = Path("selfhost/stage2_template.c")
src = path.read_text()

# Ensure is_list_name exists (mirror list of note_list)
if "is_list_name" not in src:
    if "note_list(const char *n)" in src:
        src = src.replace(
            "static void note_list(const char *n)",
            "static int is_list_name(const char *n){"
            "for(int i=0;i<g_nlists;i++)if(!strcmp(g_list_names[i],n))return 1;return 0;}"
            "\nstatic void note_list(const char *n)",
            1,
        )
    else:
        print("patch_stage2_looks_list: note_list missing — skip")
        sys.exit(0)

def repl_looks(m):
    body = m.group(0)
    if "is_list_name" in body:
        return body
    return (
        "static int looks_list(const char *e){"
        "return e&&(is_list_name(e)||strstr(e,\"sx_list_new\")||strstr(e,\"SxList\"));}"
    )

src2, n = re.subn(r"static int looks_list\(const char \*e\)\{[^}]*\}", repl_looks, src, count=1)
if n == 0:
    src2 = src
path.write_text(src2)
print("Patched looks_list for list aliases")
