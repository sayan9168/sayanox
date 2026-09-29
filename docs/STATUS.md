# Status

Last updated: 2026-09-30 (seed-min can compile compiler_min).

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
| **seed-min → gen1** | **`SEED-MIN-GEN1-OK`** | **`make seed-min-gen1`** |
| gen3 fixed point | `GEN3-OK` | `make gen3` |
| smoke / seed | SUBSET / SEED-OK | `make subset` / `make seed` |

## Dependencies

| Need | Role |
|------|------|
| **make** | Sole orchestration |
| **C compiler** | Build seeds + (optional) C backend output |
| **base64 + gzip** | Restore `compiler_min.sa` parts |
| **C seed** | Full: `sxc_seed.c` (~44KB) for gen1; **min: `sxc_seed_min.c` (~11KB)** pure-min **and** can compile `compiler_min.sa` |

**Native AOT path:** after `make native`, program output needs **no second C compile** — emits Linux x86-64 ELF directly.

```
Full:  sxc_seed.c (44KB) → gen1 → gen2 → gen3 → .c → cc
Min:   sxc_seed_min.c (11KB) → gen1 → …   (compiler_min without full seed)
Native: native_aot.c (~7KB) → ELF         (no cc for output)
```

## Verified

- `make true-selfhost` — gen1 self-compiles compiler_min → gen2
- `make native-test` — hello + while → ELF runs without clang
- `make seed-min` — pure-min reassign + while via 9KB seed
- `make seed-min-gen1` — **11KB seed compiles `compiler_min.sa` → working gen1**
- `make gen3` — gen2 recompiles compiler_min; behavioural tests pass

## Optional next

- Real per-instruction x86 emit (native currently folds then embeds output)
