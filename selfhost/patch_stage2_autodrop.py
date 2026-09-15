#!/usr/bin/env python3
"""Deep list copy on alias; string literal→heap; release on reassignment."""
from pathlib import Path
import sys

path = Path("selfhost/stage2_template.c")
src = path.read_text()

if "cannot reassign" not in src:
    print("patch_stage2_autodrop: hold path not found — skip")
    sys.exit(0)

idx = src.find("cannot reassign")
em = src.find('emit("%s = %s;\n",name,e);', idx)
if em < 0:
    em = src.find('emit("%s = %s;\\n",name,e);', idx)
if em < 0:
    print("patch_stage2_autodrop: emit not found — skip")
    sys.exit(0)

# Strip prior injects before emit
start = em
for key in ("if(k==2)", "if(k==1)"):
    s = src.rfind(key, max(0, em - 400), em)
    if s >= 0:
        start = min(start, s)

chunk_end = src.find(");", em) + 2
old_emit = src[em:chunk_end]
nl = "\\n" if "\\n" in old_emit else "\n"

# Reassignment:
#  list: drop old; if rhs list name → deep clone; else assign expr
#  string: release old; if rhs string name → dup (deep); if literal → sx_str_new; else assign
new_block = (
    f'if(k==2){{emit("sx_list_drop(&%s);{nl}",name);'
    f'if(is_list_name(e)){{emit("%s = sx_list_clone(&%s);{nl}",name,e);}}'
    f'else {{emit("%s = %s;{nl}",name,e);}}}}'
    f'else if(k==1){{emit("sx_str_release(%s);{nl}",name);'
    f'if(is_str_name(e)){{emit("%s = sx_str_dup(%s);{nl}",name,e);emit("sx_gc_track(%s);{nl}",name);}}'
    f'else if(e[0]==\'"\'){{emit("%s = sx_str_new(%s);{nl}",name,e);emit("sx_gc_track(%s);{nl}",name);}}'
    f'else {{emit("%s = %s;{nl}",name,e);emit("sx_gc_track(%s);{nl}",name);}}}}'
    f'else {{' + old_emit + f'}}'
)

src = src[:start] + new_block + src[chunk_end:]

# New list decl from list name → clone (no shared buffer)
# Replace: emit("SxList %s = %s;\n",name,e);note_list(name);if(is_list_name(e))emit retain
# With clone path
import re

def fix_new_list(m):
    return (
        'if(is_list_name(e)){'
        f'emit("SxList %s = sx_list_clone(&%s);{nl}",name,e);'
        '}else{'
        f'emit("SxList %s = %s;{nl}",name,e);'
        '}'
        'note_list(name);'
    )

# Original pattern variants
for pat in [
    r'emit\("SxList %s = %s;\\n",name,e\);note_list\(name\);if\(is_list_name\(e\)\)emit\("sx_list_retain\(&%s\);\\n",e\);',
    r'emit\("SxList %s = %s;\n",name,e\);note_list\(name\);if\(is_list_name\(e\)\)emit\("sx_list_retain\(&%s\);\n",e\);',
    r'emit\("SxList %s = %s;\\n",name,e\);note_list\(name\);',
]:
    src2, n = re.subn(pat, fix_new_list(None) if False else (
        'if(is_list_name(e)){'
        'emit("SxList %s = sx_list_clone(&%s);\\n",name,e);'
        '}else{'
        'emit("SxList %s = %s;\\n",name,e);'
        '}'
        'note_list(name);'
    ), src, count=1)
    if n:
        src = src2
        break

# New string from literal or name → always heap RC
for pat, repl in [
    (
        r'emit\("char \* %s = %s;\\n",name,e\);note_str\(name\);if\(is_str_name\(e\)\)emit\("sx_str_retain\(%s\);\\n",e\);',
        'if(is_str_name(e)||(e&&e[0]==\'"\')){'
        'emit("char *%s = sx_str_dup(%s);\\n",name,e);'
        '}else{'
        'emit("char *%s = %s;\\n",name,e);'
        '}'
        'note_str(name);emit("sx_gc_track(%s);\\n",name);',
    ),
]:
    src2, n = re.subn(pat, repl, src, count=1)
    if n:
        src = src2
        break
else:
    # simpler first-occurrence replace for note_str branch
    old = 'emit("char *%s = %s;\\n",name,e);note_str(name);'
    if old in src:
        src = src.replace(
            old,
            'if(is_str_name(e)||(e&&e[0]==\'"\')){'
            'emit("char *%s = sx_str_dup(%s);\\n",name,e);'
            '}else{'
            'emit("char *%s = %s;\\n",name,e);'
            '}'
            'note_str(name);emit("sx_gc_track(%s);\\n",name);',
            1,
        )
    old2 = 'emit("char *%s = %s;\n",name,e);note_str(name);'
    if old2 in src:
        src = src.replace(
            old2,
            'if(is_str_name(e)||(e&&e[0]==\'"\')){'
            'emit("char *%s = sx_str_dup(%s);\n",name,e);'
            '}else{'
            'emit("char *%s = %s;\n",name,e);'
            '}'
            'note_str(name);emit("sx_gc_track(%s);\n",name);',
            1,
        )

path.write_text(src)
print("Patched deep copy + literal heap promotion")
