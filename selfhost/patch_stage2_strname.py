#!/usr/bin/env python3
"""Ensure string variables use %s on show (is_str_name)."""
from pathlib import Path
import sys

path = Path("selfhost/stage2_template.c")
src = path.read_text()

if "is_str_name" not in src:
    needle = "static void note_str(const char *n)"
    if needle not in src:
        print("patch_stage2_strname: note_str missing — skip")
        sys.exit(0)
    helper = (
        "static int is_str_name(const char *n){"
        "for(int i=0;i<g_nstrs;i++)if(!strcmp(g_str_names[i],n))return 1;return 0;}"
        "\nstatic void note_str(const char *n)"
    )
    src = src.replace(needle, helper, 1)

# looks_string: also treat named string vars
old = 'static int looks_string(const char *e){if(!e)return 0;if(e[0]==\'"\')return 1;return strstr'
# try actual form
import re

def repl(m):
    body = m.group(0)
    if "is_str_name" in body:
        return body
    return body.replace(
        'if(e[0]==\'"\')return 1;',
        'if(e[0]==\'"\')return 1;if(is_str_name(e))return 1;',
        1,
    )

src2, n = re.subn(
    r"static int looks_string\(const char \*e\)\{[^}]+\}",
    repl,
    src,
    count=1,
)
if n == 0:
    # looser
    src2 = src
    if "is_str_name(e)" not in src2 and "looks_string(const char *e)" in src2:
        src2 = src2.replace(
            'if(e[0]==\'"\')return 1;',
            'if(e[0]==\'"\')return 1;if(is_str_name(e))return 1;',
            1,
        )

path.write_text(src2)
print("Patched is_str_name / looks_string")
