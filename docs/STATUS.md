# Status

Last updated: 2026-09-30 (real x86-64 native AOT).

## Entry point

```bash
make true-selfhost
```

## Summary

| Chain | Marker | Command |
|-------|--------|---------|
| full self-host | **`TRUE-FULL-SELFHOST-OK`** | **`make true-selfhost`** |
| **real native AOT** | **`NATIVE-TEST-OK`** | **`make native-test`** |
| smaller seed | `SEED-MIN-OK` | `make seed-min` |
| **seed-min → gen1** | **`SEED-MIN-GEN1-OK`** | **`make seed-min-gen1`** |
| gen3 fixed point | `GEN3-OK` | `make gen3` |

## Dependencies

| Need | Role |
|------|------|
| **make** | Sole orchestration |
| **C compiler** | Build seeds + (optional) C backend |
| **base64 + gzip** | Restore `compiler_min.sa` parts |
| **C seed** | Full ~44KB or **min ~11KB** (can compile compiler_min) |

```
Full:   sxc_seed.c (44KB) → gen1 → gen2 → gen3 → .c → cc
Min:    sxc_seed_min.c (11KB) → gen1 → …
Native: native_aot.c (~12KB) → real x86-64 ELF (no cc for output)
```

## Verified

- `make true-selfhost` — gen1 self-compiles compiler_min → gen2
- `make native-test` — **real x86-64 emit** (hold/show/while), no clang for output
- `make seed-min-gen1` — 11KB seed compiles compiler_min → gen1
- `make gen3` — behavioural fixed point

## Optional next

- (none required for bootstrap; optional polish only)
