# Status

## GEN1-OK (reassign)

```sh
make gen1
# === GEN1-OK ===
```

| Feature | Result |
|---------|--------|
| reassign (`hold n = 0` then `n = 1`) | yes |
| multi-hold + string show | yes |
| mini_in | yes |
| seed → gen1.c (no freeze) | yes |

## Partial / next

| Feature | Status |
|---------|--------|
| while / when in pure min | next |
| RHS `n = n + 1` | next |
| True Gen2 | after while/when |

## Also

- `make seed` → SEED-OK
