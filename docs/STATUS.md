# Status

Last updated: 2026-10-01 (clean-clone verified).

## Entry point

```bash
make true-selfhost
```

## Verified on clean clone (2026-10-01)

| Command | Result |
|---------|--------|
| `make true-selfhost` | **TRUE-SELFHOST-MIN-OK** |
| `make native-test` | **NATIVE-TEST-OK** (42, -42, while+done) |
| `make gen3` | **GEN3-OK** (behavioural; gen3/gen4 byte differ OK) |

## Summary

| Chain | Marker | Command |
|-------|--------|---------|
| self-host (min) | `TRUE-SELFHOST-MIN-OK` | `make true-selfhost` |
| self-host (full seed) | `TRUE-FULL-SELFHOST-OK` | `make true-selfhost-full` |
| real native AOT | `NATIVE-TEST-OK` | `make native-test` |
| gen3 | `GEN3-OK` | `make gen3` |

## Dependencies

make + C compiler + base64 + gzip. Preferred seed: `sxc_seed_min.c` (~11KB).

## Scope

Pure-min bootstrap only — not full-language self-host.
