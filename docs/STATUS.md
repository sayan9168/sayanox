# Status

## GEN1-OK (true pure path)

```sh
make gen1
# === GEN1-OK ===
```

| Step | Result |
|------|--------|
| seed compiles compiler_min.sa → gen1.c | yes |
| clang → gen1 binary | yes |
| gen1 compiles multi-hold / string / mini_in | yes |
| No cp gen1.c gen2.c freeze | yes |

Runtime: string header offsetof (not sizeof), P1 tokens, stdarg, string kind.

## Also
- make seed → SEED-OK
- make subset → smoke

## Next
- Expand pure min (while/when/reassign) for richer Gen1
- True Gen2: gen1 cannot yet compile itself (subset only)
