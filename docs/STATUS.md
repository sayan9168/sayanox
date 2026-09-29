# Status

Last updated: 2026-09-29 (pure minim compiler + Gen2 pipeline).

## Summary

| Chain | Marker | Command |
|-------|--------|---------|
| C seed smoke | `SUBSET-SELFHOST-OK` | `make subset` |
| C seed tests | `SEED-OK` | `make seed` |
| seed → gen1 (pure minim compiler) | `GEN1-OK` | `make gen1` |
| gen1 → boot → boot2 (pure pipeline) | `GEN2-PARTIAL` | `make gen2` |
| everything | all of the above | `make all` / `make test` |

Everything above runs with clang (CI, Termux) and with gcc/cc on plain Linux.
The scripts pick `$CC`, else `clang`, else `gcc`, else `cc`.

## GRAMMAR-GROW

This change extends the true gen1 target grammar in selfhost/compiler_min.sa without changing the seed -> gen1 -> boot architecture.

Implemented:
- condition text now accepts && and || chains;
- arithmetic comparison text such as pos + 1 < n is preserved into generated C;
- nested builtin identifiers in call arguments are translated to the existing sx_* helpers, including concat("a", chr(66));
- string_eq(...) is mapped to a small generated sx_eq(...) helper because compiler_min.sa uses it internally;
- selfhost/bootstrap_grammar.sh contains focused regression tests for these cases.

Required verification commands:

    make gen1
    make gen2
    ./selfhost/bootstrap_grammar.sh

The grammar-growth script additionally checks:
- when x >= 1 && x <= 3 { ... } and an || condition;
- while pos + 1 < n { ... };
- hold s = concat("a", chr(66)); show s;
- generated C contains the corresponding logical/arithmetic condition text and nested sx_cat(..., sx_chr(...)).

Verification status in this update: NOT EXECUTED IN THIS ENVIRONMENT. No GEN1-OK, GEN2-PARTIAL, or GRAMMAR-GROW-OK result is claimed here until those commands are run. If the new grammar still rejects compiler_min.sa, the remaining diagnostic should be recorded here rather than treating the grammar expansion as full self-hosting.
## GEN1-OK — the target language of `selfhost/compiler_min.sa`

`selfhost/gen1` is produced by the C seed from `selfhost/compiler_min.sa`
(no frozen C copy anywhere). It compiles this grammar:

```
program   := stmt*
stmt      := hold NAME = rhs
           | show expr
           | while NAME OP atom { stmt* }
           | when  NAME OP atom { stmt* } [ otherwise { stmt* } ]
           | }                      (closes the innermost block)
           | } otherwise {          (opens the else branch)
           | // line comment
rhs       := NUMBER | -NUMBER | NAME | "string" | NAME + NUMBER | call(...)
expr      := NUMBER | "string" | NAME | call(...)
call      := builtin( atom [, atom] )      atom := NUMBER | "string" | NAME
OP        := == | != | < | <= | > | >=
```

* `hold` on a name that was never held declares it (`double n = 0;` for
  numbers, `char *s = "x";` for strings); a later `hold` on the same name
  emits an assignment (`n = n + 1;`), tracked in the `decls`/`sdecls` tables.
* `while`/`when` bodies are handled by a brace-depth counter in the single
  character scan loop, so bodies may contain `hold`, `show`, `otherwise` and
  nested `while`/`when`.
* Numeric-only programs get standalone C (`#include <stdio.h>` plus
  `printf`/`puts`). Programs that use string builtins get ten small static
  helpers (`sx_cat`, `sx_len`, `sx_idx`, `sx_chr`, `sx_read`, `sx_write`,
  `sx_arg`, `sx_argc`, ...) emitted above `main`, so the C is still standalone.
* Builtins: `concat`/`sx_cat`, `len`/`sx_len`, `sx_index`/`sx_idx`,
  `chr`/`sx_chr`, `read_file`/`sx_read`, `write_file`/`sx_write`,
  `arg`/`sx_arg`, `arg_count`/`sx_argc`. The `sx_*` aliases are the names the
  generated C calls, so a compiler written in this grammar can emit call text
  unchanged.
* `gen1` also prints five counters to stdout (hold / show / while / when / 1)
  as a cheap self-check; the generated C goes to the output file.

The three required behaviours are covered by `make gen1`:

| Test | Program | Expected output |
|------|---------|-----------------|
| reassign | `hold n = 0` … `hold n = 2` `show n` | `2` |
| while | `while n < 3 { show n / hold n = n + 1 }` `show "done"` | `0 1 2 done` |
| when false branch | `hold x = 2` `when x == 1 { show 11 }` `show 99` | `99` only |
| when/otherwise | `hold x = 1` `when x == 1 { show 11 } otherwise { show 99 }` | `11 done` |
| nested blocks | while inside while, when inside while | `0 1 1 1 0 1 end` |
| string builtins | `sx_cat`, `sx_len`, `sx_idx`, `sx_chr` | `abcd 4 98 b` |
| subtraction / `!=` | `hold c = a - b`, `while i != 0` | `3 6`, `3 2 1 end` |
| file IO | `sx_arg`, `sx_read`, `sx_len`, `sx_write` copier | copies the file, `22 1` |

## GEN2-PARTIAL — the pure pipeline

```sh
make gen2      # === GEN2-PARTIAL ===
```

The script (`selfhost/bootstrap_gen2.sh`) never copies a translation unit:

1. the C seed is used **once**: `compiler_min.sa` → `gen1.c` → `gen1`;
2. gen1 compiles `selfhost/compiler_boot.sa` → `selfhost/boot.c` → `boot`;
3. `boot` compiles pure-min programs — reassign, while (`<`, `!=`, `-`
   operands), `when`/`otherwise`, comparison conditions like `a >= 3`, nested
   blocks, string builtins, and a file copier that uses `sx_arg`/`sx_read`/
   `sx_len`/`sx_write` — and every output is compared with gen1's;
4. `boot` compiles `compiler_boot.sa` again → `boot2.c`; **`boot2.c` is byte
   identical to `boot.c`** (checked with `cmp`) and `boot2` compiles and runs
   the same programs. That is a real fixed point of the pure pipeline, not a
   copy: both C files were produced by a compiler, from source.

### GEN2 limits (what is *not* true yet)

* gen1 cannot compile `selfhost/compiler_min.sa` itself. The pure-min grammar
  only accepts `NAME OP (NUMBER|NAME)` conditions and atom call arguments;
  `compiler_min.sa` uses `c1 >= 48 && c1 <= 57` (20 lines with `&&`), nested
  calls such as `sx_cat(nm, sx_chr(cn))`, and arithmetic in conditions.
* Therefore the fixed point applies to the pure-min dialect (the language
  `boot` is written in), **not** to the full minim compiler. Full self-host
  (gen1 compiling `compiler_min.sa`) is still open.
* `selfhost/compiler_boot.sa` deliberately supports a smaller language than
  gen1: it translates `hold`, `show`, `while`, `when`, `otherwise` with
  numbers, names, string literals and `sx_*` calls, and it copies the lines it
  does not have to translate. It is a proof of the pipeline, not a
  replacement for gen1.
* The generated helpers leak memory (no `free`): they are bootstrap-grade.

## Test commands (Termux / Linux)

```sh
# full chain
make all                     # subset + seed + gen1 + gen2
make test                    # same, ends with TEST-OK

# individual stages
make subset                  # === SUBSET-SELFHOST-OK ===
make seed                    # === SEED-OK ===
make gen1                    # === GEN1-OK ===
make gen2                    # === GEN2-PARTIAL ===

# manual, no make
CC=clang ./selfhost/bootstrap_gen1.sh
CC=gcc   ./selfhost/bootstrap_gen2.sh

# fully manual gen1 (the seed C in the repo needs the fixer applied first;
# the bootstrap scripts do this for you):
python3 selfhost/seed/apply_seed_fixes.py
gcc -O2 -o selfhost/seed/sxc_seed selfhost/seed/sxc_seed.c -I selfhost/seed
./selfhost/seed/sxc_seed selfhost/compiler_min.sa > selfhost/gen1.c
clang -O2 -o selfhost/gen1 selfhost/gen1.c -I selfhost/seed
./selfhost/gen1 selfhost/mini_in.sa selfhost/mini_out.c
clang -O2 -o selfhost/_mini selfhost/mini_out.c && ./selfhost/_mini   # 42 / done

# a program of your own through both pure compilers
printf 'hold n = 0\nwhile n < 3 {\n  show n\n  hold n = n + 1\n}\nshow "done"\n' > /tmp/loop.sa
./selfhost/gen1 /tmp/loop.sa /tmp/loop.gen1.c && $CC -O2 -o /tmp/loop.gen1 /tmp/loop.gen1.c && /tmp/loop.gen1
./selfhost/boot /tmp/loop.sa /tmp/loop.boot.c && $CC -O2 -o /tmp/loop.boot /tmp/loop.boot.c && /tmp/loop.boot
```

## Push-ready files (this change set)

```
selfhost/compiler_min.sa            target language: while/when/otherwise/reassign/strings
selfhost/compiler_boot.sa           pure compiler written in the pure-min dialect
selfhost/bootstrap_gen1.sh          seed → gen1, 12 checks (clang-first, $CC portable)
selfhost/bootstrap_gen2.sh          real pure pipeline, no `cp`, fixed-point check
selfhost/bootstrap_pure_gen2.sh     thin wrapper (kept for `make pure-gen2`)
selfhost/bootstrap_seed.sh          $CC picker instead of hardcoded clang
selfhost/bootstrap_subset.sh        $CC picker instead of hardcoded clang
Makefile                            gen2 target; clean removes boot/boot2/gen2
.github/workflows/ci.yml            gen2 job
.gitignore                          generated gen1/gen2/boot binaries and C
docs/STATUS.md                      this file
removed: selfhost/bootstrap_true_pure_gen2.sh   (did `cp gen1.c gen2.c`)
```

## Remaining work (≤5)

1. Grow the pure-min grammar until `compiler_min.sa` is inside it (`&&` in
   conditions, two-operand comparison like `pos + 1 < n`, nested call
   arguments) so gen1 can compile the compiler itself.
2. Keep `docs/VNEXT_STATUS.md` honest: the "fake gen2" item it lists is fixed
   by this change set; the other items (dead base64/blob dirs, missing std
   runner, `install_sxc_full.py` referenced by `restore_sxc_full.sh`) are not.
3. Replace the `char *`/`double` split in generated C with a tagged value type
   once the grammar supports `str()` and mixed arithmetic.
4. Add a `make conformance` runner so the pure-min examples live in one place
   instead of the two bootstrap scripts.
5. Retire the remaining base64/gz seed artifacts once `make all` is the only
   documented path.
