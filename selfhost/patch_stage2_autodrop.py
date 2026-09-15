#!/usr/bin/env python3
"""Auto-drop list on hold reassignment; retain when copying list expr if needed."""
from pathlib import Path
import sys

path = Path("selfhost/stage2_template.c")
src = path.read_text()

old = (
    'if(k!=nk){fprintf(stderr,"stage2: %s:%d: error: cannot reassign \'%s\' to a different type\n",'
    'g_path?g_path:"input",cur()->line,name);exit(1);}'
    'emit("%s = %s;\\n",name,e);'
)
# Actual source uses escaped differently - search flexible
marker = 'cannot reassign'
if marker not in src:
    print("patch_stage2_autodrop: hold path not found — skip")
    sys.exit(0)

# Replace the emit after type-check on reassignment
target = 'emit("%s = %s;\n",name,e);'
# In file as emit("%s = %s;\n",name,e) inside the is_declared branch only once near reassign
idx = src.find("cannot reassign")
if idx < 0:
    sys.exit(0)
# find emit after this
em = src.find('emit("%s = %s;\n",name,e);', idx)
if em < 0:
    em = src.find('emit("%s = %s;\\n",name,e);', idx)
if em < 0:
    print("patch_stage2_autodrop: emit not found — skip")
    sys.exit(0)

# Determine exact substring length
end = src.find(';', em) + 1
# include closing paren style emit("%s = %s;\n",name,e);
chunk_end = src.find(');', em) + 2
old_emit = src[em:chunk_end]
new_emit = (
    'if(k==2)emit("sx_list_drop(&%s);\\n",name);'
    'emit("%s = %s;\\n",name,e);'
)
# Match escaping style of old_emit
if '\\n' in old_emit:
    new_emit = (
        'if(k==2)emit("sx_list_drop(&%s);\\n",name);'
        + old_emit
    )
else:
    new_emit = (
        'if(k==2)emit("sx_list_drop(&%s);\n",name);'
        + old_emit
    )

src2 = src[:em] + new_emit + src[chunk_end:]
path.write_text(src2)
print("Patched auto-drop on list reassignment")
