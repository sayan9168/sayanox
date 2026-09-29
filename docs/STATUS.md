# Status

Last updated: 2026-09-30 (native AOT + smaller seed).

## Entry point

```bash
make true-selfhost
```

## Summary

| Chain | Marker | Command |
|-------|--------|---------|
| full self-host | **`TRUE-FULL-SELFHOST-OK`** | **`make true-selfhost`** |
| native AOT | `NATIVE-TEST-OK` | `make native-test` |
| smaller seed | `SEED-MIN-OK` | `make seed-min` |
| smoke / seed | SUBSET / SEED-OK | `make subset` / `make seed` |

## Dependencies

| Need | Role |
|------|------|
| **make** | Sole orchestration |
| **C compiler** | Build seeds + (optional) C backend output |
| **base64 + gzip** | Restore `compiler_min.sa` parts |
| **C seed** | Full: `sxc_seed.c` (~44KB) for gen1; **min: `sxc_seed_min.c` (~9KB)** for pure-min |

**Native AOT path:** after `make native`, program output needs **no second C compile** — emits Linux x86-64 ELF directly.

```
Full:  sxc_seed.c (44KB) → gen1 → gen2 → .c → cc
Min:   sxc_seed_min.c (9KB) → .c → cc     (pure-min only)
Native: native_aot.c (~7KB) → ELF         (no cc for output)
```

## Verified

- `make true-selfhost` — gen1 self-compiles compiler_min → gen2
- `make native-test` — hello + while → ELF runs without clang
- `make seed-min` — pure-min reassign + while via 9KB seed

## Optional next

- Byte-identical gen3 fixed point
- Grow native AOT / seed-min toward compiling `compiler_min.sa` without full seed
