# Status

## Done (Stage-3 unified sxc)
```sh
make selfhost
./selfhost/sxc in.sa out.c   # CLI
# output: 0 1 2 42 99
```

| Feature | Status |
|---------|--------|
| make / give / call | ✅ |
| hold / show | ✅ |
| while | ✅ |
| when / elif / otherwise | ✅ |
| CLI arg paths | ✅ |
| Native AOT (separate) | ✅ many features |
| sxpkg fetch/types | ✅ |
| gc / gc_step | ✅ cooperative |

## Still remaining (honest)
1. **Full static type checker** (beyond tags + Stage-2 decls)
2. **OS-thread concurrent GC** (native has no pthread)
3. **Stage2-free bootstrap** of sxc itself (still need stage2 once)
4. **Richer exprs** in sxc (floats, lists, strings in self-host path)
5. **Unified native + self-host** (one backend only)
6. **LSP / package registry online** (local + fetch URL only)
