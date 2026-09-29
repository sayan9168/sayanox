# Status

Last updated: 2026-09-30 (polish: min-default, real x86, quiet self-compile).

## Entry point

```bash
make true-selfhost          # preferred: seed-min → gen1 → gen2
# make true-selfhost-full   # optional: 44KB full C seed path
```

## Summary

| Chain | Marker | Command |
|-------|--------|---------|
| **self-host (min)** | **`TRUE-SELFHOST-MIN-OK`** | **`make true-selfhost`** |
| self-host (full seed) | `TRUE-FULL-SELFHOST-OK` | `make true-selfhost-full` |
| real native AOT | `NATIVE-TEST-OK` | `make native-test` |
| seed-min → gen1 | `SEED-MIN-GEN1-OK` | `make seed-min-gen1` |
| gen3 / gen4 | `GEN3-OK` | `make gen3` |

## Dependencies

| Need | Role |
|------|------|
| **make** | Sole orchestration (no bash entry scripts) |
| **C compiler** | Build seed binaries; optional C backend for `.c` output |
| **base64 + gzip** | Restore `compiler_min.sa` from parts |
| **C seed** | **Preferred: `sxc_seed_min.c` (~11KB)**; optional full `sxc_seed.c` (~44KB) |

```
Preferred: sxc_seed_min (11KB) → gen1_min → gen2 → gen3
Full:      sxc_seed (44KB)     → gen1 → gen2
Native:    native_aot (~11KB)  → real x86-64 ELF (no second cc)
```

## Verified

- `make true-selfhost` — seed-min path, no debug `show` spam
- `make native-test` — real x86-64 (26 slots, signed itoa)
- `make gen3` — behavioural fixed point (gen3→gen4)

## Optional polish (done 2026-09-30)

1. gen3→gen4 fixed-point check
2. Removed trailing `show holds/shows/...` from `compiler_min.sa`
3. Default bootstrap is seed-min (full seed optional)
4. Native: 26 variable slots, negative numbers
5. Docs: STATUS + CONTRIBUTING + BOOTSTRAP entry notes
