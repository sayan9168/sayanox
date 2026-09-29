# Status

## GEN1-OK (expanded pure min)

```sh
make gen1
# === GEN1-OK ===
```

| Feature | Result |
|---------|--------|
| reassign (`hold n = 0` then `n = 1`) | yes |
| RHS `n = n + 1` | yes |
| `while n < 3 { ... }` | yes |
| `when x == 1 { ... }` | yes |
| show number / name / string | yes |
| seed → gen1.c (no freeze copy) | yes |

## Also

- `make seed` → SEED-OK
- `make subset` → smoke

## Limits

- Pure min target language still a subset (no `make` functions, no `otherwise` yet, no string ops in user programs).
- True Gen2 (gen1 compiles `compiler_min.sa` itself) needs the pure min language to cover its own implementation features — next phase.

## Next

1. `otherwise` branch for `when`
2. Expand pure min until it can compile a reduced self-host source
3. True Gen2 without `cp gen1.c gen2.c`
