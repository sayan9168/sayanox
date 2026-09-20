# Pure Sayanox self-host loop

```
sxc_full  →  compiler_min.sa  →  gen1
gen1      →  mini_*.sa        →  runnable C
```

## Proven
| Step | Result |
|------|--------|
| Gen1 from pure `.sa` | ✅ |
| Gen1 → while/when/make | ✅ 0 1 2 42 99 |
| Gen1 → field `p.x` | ✅ 3 4 |
| Gen1 → list/struct/string | ✅ |
| Deterministic | ✅ |

## Run
```sh
./selfhost/bootstrap_selfhost_loop.sh
# SELFHOST-LOOP-OK
```

## Next
Gen1 compiles `compiler_min.sa` itself (requires hold RHS builtins:
`read_file`, `concat`, `chr`, `str`, `len`, indexing).
