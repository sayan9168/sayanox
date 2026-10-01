#!/usr/bin/env python3
"""Inject string_eq→sx_eq crepl rewrite into compiler_min.sa if missing."""
import sys
from pathlib import Path

path = Path(sys.argv[1] if len(sys.argv) > 1 else "selfhost/compiler_min.sa")
t = path.read_text()
if "hold crepl" in t and "concat(body, crepl)" in t:
    print(f"[OK] crepl already present in {path}")
    sys.exit(0)

old = """      hold ctrim = \"\"
      hold ci = 0
      while ci < cl {
        hold ctrim = concat(ctrim, chr(sx_index(cond,ci)))
        hold ci = ci + 1
      }
      when pos < n {
"""

new = """      hold ctrim = \"\"
      hold ci = 0
      while ci < cl {
        hold ctrim = concat(ctrim, chr(sx_index(cond,ci)))
        hold ci = ci + 1
      }
      hold crepl = \"\"
      hold cri = 0
      hold crl = len(ctrim)
      while cri < crl {
        hold matched = 0
        when cri + 9 <= crl {
          hold slice = \"\"
          hold sj = 0
          while sj < 9 {
            hold slice = concat(slice, chr(sx_index(ctrim, cri + sj)))
            hold sj = sj + 1
          }
          when string_eq(slice, \"string_eq\") {
            hold crepl = concat(crepl, \"sx_eq\")
            hold cri = cri + 9
            hold matched = 1
          }
        }
        when matched == 0 {
          hold crepl = concat(crepl, chr(sx_index(ctrim, cri)))
          hold cri = cri + 1
        }
      }
      when pos < n {
"""

if old not in t:
    print(f"FAIL: ctrim pattern not found in {path}", file=sys.stderr)
    sys.exit(1)
t = t.replace(old, new, 1)
t = t.replace("concat(body, ctrim)", "concat(body, crepl)")
# strip debug shows
lines = [L for L in t.splitlines() if L.strip() not in ("show holds", "show shows", "show whiles", "show whens", "show 1")]
t = "\n".join(lines) + "\n"
path.write_text(t)
print(f"[OK] patched crepl into {path} ({len(t)} bytes)")
