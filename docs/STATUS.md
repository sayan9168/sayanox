# Status

Last updated: 2026-09-30 (Makefile-only; no bash scripts).

## Entry point

```bash
make true-selfhost
```

That is the **only** supported bootstrap entry. There are no `bootstrap_*.sh` scripts.

## Summary

| Chain | Marker | Command |
|-------|--------|---------|
| smoke + seed | `SUBSET-SELFHOST-OK` / `SEED-OK` | `make subset` / `make seed` |
| seed → gen1 | `GEN1-OK` | `make gen1` |
| gen1 → gen2 | `GEN2-OK` | `make gen2` |
| **full self-host** | **`TRUE-FULL-SELFHOST-OK`** | **`make true-selfhost`** |
| everything | TEST-OK | `make all` / `make test` |

## Dependencies (final)

| Need | Role |
|------|------|
| **make** | Sole orchestration entry |
| **C compiler** (clang/gcc/cc) | Compile seed + emitted C |
| **base64 + gzip** | Restore `compiler_min.sa` from split parts (Unix coreutils) |
| **C seed** (once) | `sxc_seed.c` + `sx_runtime.h` — trusted bootstrap |

**Not required:** bash scripts, Python, Node, Rust, or any other language.

```
C seed (once)  →  gen1 (.sa compiler)  →  gen2 (self-compiled)  →  programs
```

## Verified

- gen1 compiles `compiler_min.sa` → working gen2
- gen2 ≠ frozen copy of gen1.c
- reassign / while / when / boot_from_gen2 pass

## Remaining optional

- Byte-identical gen3 fixed point
- Smaller C seed / native AOT to shrink the C dependency further
