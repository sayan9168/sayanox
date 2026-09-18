# Native path ≈ Stage-2 IR

The native AOT compiler uses an internal pipeline similar to Stage-2:

```
source .sa
  → preprocess (use "mod.sa")
  → statements (estmt)
  → expression trees (parse_expr)
  → machine-code emission (x86_64)
```

## Covered Stage-2 surface on native

| Feature | Native |
|---------|--------|
| hold / show | yes |
| arith / compare | yes |
| when / otherwise / while | yes |
| make / call | yes |
| lists / push / len | yes |
| strings + runtime concat | yes |
| gc() mark-copy | yes (STW to-space) |
| use modules | yes |
| write_file / read_file / run | yes |

## Still on Stage-2 C path only

- Full concurrent pthread GC (see docs/GC.md)
- Broadest struct/generic lowering
- Compiler self-host of entire compiler.sa
