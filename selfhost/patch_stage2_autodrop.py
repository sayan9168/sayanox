#!/usr/bin/env python3
"""Deep list clone + literal/string heap promotion + release on reassignment."""
from pathlib import Path
import sys

path = Path("selfhost/stage2_template.c")
src = path.read_text()

old = 'if(k!=nk){fprintf(stderr,"stage2: %s:%d: error: cannot reassign \'%s\' to a different type\\n",g_path?g_path:"input",cur()->line,name);exit(1);}emit("%s = %s;\\n",name,e);'
new = (
    'if(k!=nk){fprintf(stderr,"stage2: %s:%d: error: cannot reassign \'%s\' to a different type\\n",g_path?g_path:"input",cur()->line,name);exit(1);}'
    'if(k==2){emit("sx_list_drop(&%s);\\n",name);if(is_list_name(e))emit("%s = sx_list_clone(&%s);\\n",name,e);else emit("%s = %s;\\n",name,e);}'
    'else if(k==1){emit("sx_str_release(%s);\\n",name);if(e[0]==\'"\'||is_str_name(e)){emit("%s = sx_str_dup(%s);\\n",name,e);emit("sx_gc_track(%s);\\n",name);}else emit("%s = %s;\\n",name,e);}'
    'else emit("%s = %s;\\n",name,e);'
)
if old not in src:
    print("patch_stage2_autodrop: reassign pattern missing — skip")
    sys.exit(0)
src = src.replace(old, new, 1)

old2 = 'emit("SxList %s = %s;\\n",name,e);note_list(name);'
if old2 in src:
    src = src.replace(
        old2,
        'if(is_list_name(e))emit("SxList %s = sx_list_clone(&%s);\\n",name,e);else emit("SxList %s = %s;\\n",name,e);note_list(name);',
        1,
    )

old3 = 'emit("char *%s = %s;\\n",name,e);note_str(name);'
if old3 in src:
    src = src.replace(
        old3,
        'if(e[0]==\'"\'||is_str_name(e)){emit("char *%s = sx_str_dup(%s);\\n",name,e);emit("sx_gc_track(%s);\\n",name);}else emit("char *%s = %s;\\n",name,e);note_str(name);',
        1,
    )

path.write_text(src)
print("Patched deep clone + literal heap + release")
