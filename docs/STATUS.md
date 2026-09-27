# Status

## Seed compiler (Phase 2) — SEED-OK

```sh
make seed
# === SEED-OK ===
```

Fixed in `selfhost/seed/sxc_seed.c` + `sx_runtime.h`:

| Bug | Fix |
|-----|-----|
| Operator token string was `'<'` not `<` | P1 macro uses 1-char buffer |
| Output only to stdout | `sxc_seed in.sa out.c` or `-o out.c` |
| `sx_n` undeclared | default return `0.0` |
| Missing `stdarg.h` in generated C | emitted in prologue |
| String kind miss (data vs header) | `sx_kind` recovers string header |

Verified: hold, when/otherwise, while, make/give, index, concat, len, reassign, list, mini2.

## CI

- `subset` — minimal smoke
- `seed` — full seed suite (hard fail)

## Next

- True Gen1 from pure `compiler_min.sa` via seed
- Gen2 without `cp gen1.c gen2.c`
