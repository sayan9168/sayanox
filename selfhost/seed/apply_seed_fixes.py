#!/usr/bin/env python3
"""Apply critical seed/runtime fixes before building the seed."""
from pathlib import Path

def patch_seed():
    p = Path("selfhost/seed/sxc_seed.c")
    t = p.read_text()
    changed = False
    old = "#define P1(ch,k) if(c==ch){ i++; col++; ptok(k,(const char*)#ch,0,sl,sc); continue; }"
    new = "#define P1(ch,k) if(c==ch){ i++; col++; { char _b[2]={(char)(ch),0}; ptok(k,_b,0,sl,sc);} continue; }"
    if old in t:
        t = t.replace(old, new, 1); changed = True
    if "return sx_n(0);" in t:
        t = t.replace("return sx_n(0);", "return 0.0;"); changed = True
    needle = 'fputs("#include \\"sx_runtime.h\\"\\n\\n",out);'
    if needle in t:
        t = t.replace(needle, 'fputs("#include \\"sx_runtime.h\\"\\n#include <stdarg.h>\\n\\n",out);', 1)
        changed = True
    if changed:
        p.write_text(t); print("patched sxc_seed.c")
    else:
        print("sxc_seed.c ok")

def patch_runtime():
    r = Path("selfhost/seed/sx_runtime.h")
    rt = r.read_text()
    orig = rt
    if "#include <stddef.h>" not in rt:
        rt = rt.replace("#include <stdint.h>", "#include <stdint.h>\n#include <stddef.h>", 1)
    rt = rt.replace(
        "static SxStrHdr *sx_sh(const char*p){ return p?(SxStrHdr*)((char*)p-sizeof(SxStrHdr)):NULL; }",
        "static SxStrHdr *sx_sh(const char*p){ return p?(SxStrHdr*)((char*)p-offsetof(SxStrHdr,data)):NULL; }",
    )
    rt = rt.replace(
        "SxStrHdr*h=malloc(sizeof(*h)+n+1);",
        "SxStrHdr*h=malloc(offsetof(SxStrHdr,data)+n+1);",
    )
    if "Recover header via offsetof" not in rt:
        oldk = """static int sx_kind(double v){
  if(v!=v) return 0;                       /* NaN -> num */
  double a=v<0?-v:v;
  if(a<4096.0 || a>1e15) return 0;         /* implausible pointer range -> num */
  uintptr_t p=(uintptr_t)(long long)v;
  if(p&7) return 0;                        /* malloc headers are 8-aligned */
  int i=sx_tab_find((void*)p);
  return i<0?0:(int)sx_tab_kind[i];
}"""
        newk = """static int sx_kind(double v){
  if(v!=v) return 0;
  double a=v<0?-v:v;
  if(a<4096.0 || a>1e15) return 0;
  uintptr_t p=(uintptr_t)(long long)v;
  if(p&7) return 0;
  int i=sx_tab_find((void*)p);
  if(i>=0) return (int)sx_tab_kind[i];
  if(p > sizeof(SxStrHdr)+8){
    SxStrHdr *h = (SxStrHdr*)((char*)(void*)p - offsetof(SxStrHdr, data));
    i = sx_tab_find(h);
    if(i>=0 && sx_tab_kind[i]==1) return 1;
  }
  return 0;
}"""
        if oldk in rt:
            rt = rt.replace(oldk, newk, 1)
    if rt != orig:
        r.write_text(rt); print("patched sx_runtime.h")
    else:
        print("sx_runtime.h ok")

if __name__ == "__main__":
    patch_seed()
    patch_runtime()
