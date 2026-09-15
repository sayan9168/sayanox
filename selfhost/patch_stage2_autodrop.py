#!/usr/bin/env python3
"""Auto-drop/release on reassignment; retain on list/string alias."""
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

# Remove any previous auto-drop inject immediately before this emit
before = src[max(0, em - 120) : em]
if "sx_list_drop" in before:
    # find start of if(k==2)emit drop
    start = src.rfind("if(k==2)", max(0, em - 200), em)
    if start >= 0:
        src = src[:start] + src[em:]
        em = start

chunk_end = src.find(");", em) + 2
old_emit = src[em:chunk_end]
nl = "\\n" if "\\n" in old_emit else "\n"

# On reassignment:
#  list: drop old; if rhs is list name, retain source; then assign
#  string: release old heap string; if rhs is str name, retain; then assign
new_block = (
    f'if(k==2){{emit("sx_list_drop(&%s);{nl}",name);'
    f'if(is_list_name(e))emit("sx_list_retain(&%s);{nl}",e);}}'
    f'if(k==1){{emit("sx_str_release(%s);{nl}",name);'
    f'if(is_str_name(e))emit("sx_str_retain(%s);{nl}",e);}}'
    + old_emit
)

src = src[:em] + new_block + src[chunk_end:]

# New decl: hold ys = xs (list alias) → retain source
# after note_list(name) for new list decl from expr
needle = 'note_list(name);'
if needle in src and "sx_list_retain" not in src[src.find(needle) : src.find(needle) + 80]:
    src = src.replace(
        needle,
        needle + f'if(is_list_name(e))emit("sx_list_retain(&%s);{nl}",e);',
        1,
    )

# New string decl from another string name
needle2 = 'note_str(name);'
if needle2 in src and "sx_str_retain" not in src[src.find("looks_string(e)){note_decl") : src.find("looks_string(e)){note_decl") + 200]:
    # only first note_str after looks_string branch - careful
    pos = src.find("looks_string(e)){note_decl_k(name,1)")
    if pos >= 0:
        ns = src.find(needle2, pos)
        if ns >= 0 and "sx_str_retain" not in src[ns : ns + 60]:
            src = src[: ns + len(needle2)] + f'if(is_str_name(e))emit("sx_str_retain(%s);{nl}",e);' + src[ns + len(needle2) :]

path.write_text(src)
print("Patched auto-drop/release + alias retain")
