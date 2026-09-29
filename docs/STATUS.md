# Status

Last updated: 2026-09-29 (TRUE FULL SELF-HOST).

## Summary

| Chain | Marker | Command |
|-------|--------|---------|
| C seed smoke | `SUBSET-SELFHOST-OK` | `make subset` |
| C seed tests | `SEED-OK` | `make seed` |
| seed → gen1 (pure minim compiler) | `GEN1-OK` | `make gen1` |
| gen1 → boot → boot2 (pure pipeline) | `GEN2-PARTIAL` | `make gen2` |
| **gen1 compiles compiler_min → gen2** | **`TRUE-FULL-SELFHOST-OK`** | `bash selfhost/bootstrap_true_selfhost.sh` |
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

1. **Declaration hoisting** – first `hold` (even inside nested when/while) emits
   `type name = 0;` / `char *name = "";` into a top-level `decls_c` block;
   the body always gets an assignment. Nested first-holds stay in scope.
2. **String escape hardening** – `\` in a source string literal emits `\` into C;
   `\"` emits `\"`. Closing quotes no longer break the generated C.
3. **`string_eq` → `sx_eq` in conditions** – condition text is scanned and every
   occurrence of the identifier `string_eq` is rewritten to the generated helper
   `sx_eq` before emission.
4. **`SX_TAB_CAP` raised to 2 097 152** – self-compile of the ~43 KB source
   allocates enough tagged strings; the default 262 144 overflowed.

### Remaining optional work

- Quadratic `concat` on large sources (no lists in pure-min) – self-compile of
  compiler_min takes ~60–90 s. A list-based body builder would make it fast.
- Byte-identical fixed point of gen2 recompiling compiler_min (gen3 vs gen2)
  is not yet asserted; behavioural agreement is verified via the boot path.

## GEN1-OK target language

`selfhost/gen1` (and `gen2`) accept:

```
hold NAME = NUMBER | NAME | "string" | NAME + NUMBER | call(...)
show  NUMBER | NAME | "string" | call(...)
while COND { ... }
when  COND { ... } [ otherwise { ... } ]
// line comments
```

COND is copied as C expression text (supports `&&` / `||` / arithmetic).
Call names `concat`/`len`/`sx_index`/`chr`/`read_file`/`write_file`/`arg`/
`arg_count`/`string_eq` map to the emitted static helpers.
