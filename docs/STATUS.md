# Status

Last updated: 2026-09-30 (TRUE FULL SELF-HOST; Makefile-only entry).

## Summary

| Chain | Marker | Command |
|-------|--------|---------|
| C seed smoke | `SUBSET-SELFHOST-OK` | `make subset` |
| C seed tests | `SEED-OK` | `make seed` |
| seed → gen1 (pure minim compiler) | `GEN1-OK` | `make gen1` |
| gen1 → boot → boot2 (pure pipeline) | `GEN2-PARTIAL` | `make gen2` |
| **gen1 compiles compiler_min → gen2** | **`TRUE-FULL-SELFHOST-OK`** | **`make true-selfhost`** |
| everything | all of the above | `make all` / `make test` |

Everything above runs with clang (CI, Termux) and with gcc/cc on plain Linux.

## TRUE FULL SELF-HOST

```
C seed (once)     : compiler_min.sa → gen1.c → gen1
gen1 (pure)       : compiler_min.sa → gen2.c → gen2     ← live self-compile
gen2              : pure-min programs (reassign/while/when)
gen2              : compiler_boot.sa → boot_from_gen2    ← third generation
```

Verified:

- gen1 compiles its own source (`compiler_min.sa`) into working gen2
- gen2 is not a frozen copy of gen1.c
- gen2 runs reassign / while / when correctly
- gen2 builds `compiler_boot.sa` which then compiles pure-min programs

### Fixes that closed the gap

1. **Declaration hoisting** – first `hold` emits decls into top-level `decls_c`
2. **String escape hardening** – `\` / `\"` emit correctly into C
3. **`string_eq` → `sx_eq` in conditions**
4. **`SX_TAB_CAP` 2 097 152** for self-compile
5. **Body chunking** at 4096 chars
6. **P1 token macro** – operators store `+` not `'+'`
7. **String object table** – register data ptr (matches `sx_pack`), not header

### Language dependencies (bootstrap)

| Layer | Language | Role |
|-------|----------|------|
| Trusted seed | **C only** | `sxc_seed.c` + `sx_runtime.h` — once |
| Compiler | **`.sa` only** | `compiler_min.sa` → gen1 → gen2 |
| Orchestration | **make** | `make true-selfhost` (primary) |
| C compiler | clang/gcc/cc | Compile seed + emitted C |

**Primary entry: `make true-selfhost`.** No bash script required.
Seed fixes (P1, offsetof, string-tab) apply via make recipes; `compiler_min.sa`
restores from gzip+b64 parts with `base64` + `gzip`. Bash scripts are thin
wrappers that call `make`. Python is not used on the happy path.

### Remaining optional work

- Byte-identical fixed point of gen2 recompiling compiler_min (gen3 vs gen2)
- List-based body builder (dialect growth) for further speed if needed

## GEN1-OK target language

```
hold NAME = NUMBER | NAME | "string" | NAME + NUMBER | call(...)
show  NUMBER | NAME | "string" | call(...)
while COND { ... }
when  COND { ... } [ otherwise { ... } ]
```
