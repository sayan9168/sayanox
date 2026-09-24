# Status

## PURE-EMIT-OK

```sh
./selfhost/bootstrap_pure_emit.sh
# === PURE-EMIT-OK ===
```

| Path | Index | Reassign | mini_in2 |
|------|-------|----------|----------|
| sxc_full (seed) | yes | yes | yes |
| gen1 (pure min) | partial | yes via fixup_emit | yes |

## Tools
- `selfhost/fixup_emit.c` — second `double x =` becomes `x =`

## Next
- Pure min: emit sx_index for msg[i]
- Live gen2_raw clang-clean without gen1.c copy
