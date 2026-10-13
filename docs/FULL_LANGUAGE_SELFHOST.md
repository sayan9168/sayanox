# Full-language self-host

Rewritten 2026-10-13. The previous version of this file described a Stage-2 C
host, a `make stage2` target and a `bootstrap_full_language_selfhost.sh`
one-command bootstrap. **None of those exist in this repository** — see
"The Stage-2 host is not in this repository" below. Everything on this page is
either verified by a `make` target or explicitly labelled as missing.

## What actually runs

```bash
make doctor && make true-selfhost && make gen3 && make native-test
```

| Layer | Written in | What it does | Gate |
|---|---|---|---|
| `selfhost/seed/sxc_seed_min.c` | C, ~950 lines | compiles the pure-min dialect; it is the only hand-written compiler in the chain | `make true-selfhost` |
| `selfhost/compiler_min.sa` → `selfhost/gen1_min.c` → `selfhost/gen2.c` | **Sayanox**, ~17,200 lines | the compiler source; seed-min compiles it into gen1_min, gen1_min compiles it into gen2 | `make true-selfhost` |
| `gen2` → `gen3.c` → `gen4.c` | Sayanox (gen2's own output) | gen3 and gen4 must be **byte-identical** | `make gen3` |
| `selfhost/native_aot.c` | C, ~4,000 lines | x86-64 Linux machine code for the native subset | `make native-test` |

Every compiler above the C seed is written in Sayanox and compiled by the layer
below it. That is the whole self-hosting claim, and `gen3 == gen4` checks it on
every run. `make true-selfhost-min` runs ~55 feature gates against gen2 before
that comparison.

## What the Sayanox-written compiler supports

Each line names the gate that pins it. This is a growing subset of the full
language, not the full language.

* `hold` / `show` / `when` / `otherwise` (`else`, `elif`, `else when`,
  `else if`, `otherwise when`) / `while` / `give` — `test-reassign`,
  `test-while`, `test-when`, `test-gen2-gaps`, `test-give-index`
* numbers as IEEE doubles, `+ - * / %` with `%` lowered through a checked
  `sx_mod`, integer tokens emitted as doubles — `test-float`, `test-mod`,
  `test-prec`
* strings: literals, `concat`, `chr`, `len`, `s[i]`, content `==`/`!=` and
  `< <= > >=`, string `for` — `test-for-str`, `test-gen2-gaps`,
  `test-native-strord`
* lists: literals, `push`, `len`, `xs[i]`, list returns from functions,
  typed inline list expressions — `test-list2`, `test-list-expr`,
  `test-list-paren`
* structs: declarations, literals, nested structs, field chains, field types
  inferred from the literals that fill them — `test-struct2`, `test-struct-logic`
* fully typed functions (`make f(a: num, b: str) -> str`), forward and mutual
  recursion, function-local `hold`, function-local `for`, parameters that are
  reassigned — `test-typed-sig`, `test-fn2`, `test-seed-typed-functions`
* `for` over a variable, a literal, a checked call, a dotted field chain and a
  numeric range, inside and outside typed and untyped `make` bodies —
  `test-seed-for-literals`, `test-seed-for-range`, `test-seed-for-calls`,
  `test-seed-for-untyped`, `test-seed-for-fields`
* **index expressions (2026-10-13):** `xs[i - 1]`, `xs[(a + b) / 2]`,
  `xs[p.k]` in a value position, inside a `when`/`while` condition and inside a
  `for` bound, lowered to `sx_lget`/`sx_idx` — `test-gen2-index-expr`
* generics over numbers (`make NAME<T>`, `NAME<A, B>`), demand-driven generic
  bodies — `test-generics`, `test-native-generics`
* `use "file.sa"` splicing to depth 8 — `test-use`
* a mark & sweep collector with `gc()`, `gc_live()`, `gc_runs()` — `test-gc`,
  `docs/GC.md`
* the stdlib: seven modules, ~120 helpers — `test-stdlib`,
  `test-stdlib-modules`, `docs/STDLIB.md`

## What it refuses, with a diagnostic instead of wrong code

* `%`, a call (including `len()`), a nested index, a comma, a quoted string, an
  empty index, unbalanced parentheses or a trailing operator inside `[ ]`
  (`make test-gen2-index-expr` pins all 13 refusals)
* a bare string `+` chain in a `give` (`give "hi " + name`): gen2 emits C that
  does not compile. Accumulate into a `hold` and return that.
* a global read inside an untyped `make` body
* `for v in p.xs` (a `list`-typed struct field as the source) and
  `for c in (s)` (a parenthesised source)
* a native-only construct on the portable path, and vice versa

The full list, with the backend that differs, is in `docs/STATUS.md` under
"Measured divergences".

## The Stage-2 host is not in this repository

Measured on 2026-10-13:

| Referenced by the old docs | Actual state |
|---|---|
| `make stage2` | no such target in the Makefile |
| `selfhost/bootstrap_full_language_selfhost.sh`, `selfhost/bootstrap_full_selfhost.sh` | no such files |
| `selfhost/stage2_template.c` | 93 bytes: a `PLACEHOLDER` comment |
| `selfhost/stage2_src/` | a README and an 11-byte `b64_0.txt` reading `PLACEHOLDER` |
| `selfhost/sxc_full.c` | 30 lines; lowers only `hold NAME = <digits>` and `show` |
| `./selfhost/restore_stage2.sh` | exits 1: `error: missing Stage-2 seed; expected plain selfhost/sxc_full.c or selfhost/stage2_src/*.c` |

`make test-doc-claims` fails if those references reappear in `docs/`, so this
page cannot drift back into claiming a host that is not there.

There is therefore no C host that lowers "the full grammar". The way the
language grows is one increment at a time inside
`selfhost/compiler_min.sa` — Sayanox source, compiled by the C seed, gated by a
`make` target — and every increment is recorded in `docs/STATUS.md` with what it
does and does not claim.

## Editing the compiler source: two constraints found the hard way

1. **All `make` definitions belong in the leading block** (lines 1-841 of
   `compiler_min.sa`, before any top-level statement). A definition placed
   after ~2,400 lines of top-level code was not parsed as one: gen1_min emitted
   `raw_index(double source, double str, double from, double num, double n,
   double num)` — the annotations split into extra parameters — and gen2.c did
   not compile. This is a property of the compiler's own source layout, not of
   user programs.
2. **A name shared by two blocks must be declared at the top.** The compiler
   source contains two copies of the expression parser; a first `hold` inside a
   block becomes a C local of *that* block, so the second copy then references
   an undeclared name. Shared scan variables live in the declaration block
   around lines 1250-2000.
