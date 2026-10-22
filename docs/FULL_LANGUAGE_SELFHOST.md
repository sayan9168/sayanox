# Full-language self-host

Updated 2026-10-17. The previous version of this file described a Stage-2 C
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
| `selfhost/seed/sxc_seed_min.c` | C, ~1,965 lines | compiles the pure-min dialect; it is the only hand-written compiler in the chain | `make true-selfhost` |
| `selfhost/compiler_min.sa` → `selfhost/gen1_min.c` → `selfhost/gen2.c` | **Sayanox**, 18,713 lines including the live text module | the compiler source; seed-min compiles it into gen1_min, gen1_min compiles it into gen2 | `make true-selfhost` |
| `gen2` → `gen3.c` → `gen4.c` | Sayanox (gen2's own output) | gen3 and gen4 must be **byte-identical** | `make gen3` |
| `selfhost/native_aot.c` | C, ~4,000 lines | x86-64 Linux machine code for the native subset | `make native-test` |

Every compiler above the C seed is written in Sayanox and compiled by the layer
below it. That is the whole self-hosting claim, and `gen3 == gen4` checks it on
every run. `make true-selfhost-min` runs feature gates against gen2 before
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
  inferred from the literals that fill them — `test-struct2`, `test-struct-logic`; all three backends support concrete list-pointer fields and `for v in p.xs`. `test-list-struct-fields` runs shared alias/iteration output on all three and native GC; `test-gen2-list-struct-fields` additionally proves Gen2's `sx_list *` layout, literals/copies, indexed read/write, conditions and nested iteration.
* fully typed functions (`make f(a: num, b: str) -> str`), forward and mutual
  recursion, function-local `hold`, function-local `for`, parameters that are
  reassigned — `test-typed-sig`, `test-fn2`, `test-seed-typed-functions`
* `for` over a variable, a literal, a checked call, a dotted field chain and a
  numeric range, inside and outside typed and untyped `make` bodies —
  `test-seed-for-literals`, `test-seed-for-range`, `test-seed-for-calls`,
  `test-seed-for-untyped`, `test-seed-for-fields`
* **index expressions (2026-10-13):** `xs[i - 1]`, `xs[(a + b) / 2]`,
  `xs[p.k]`, `xs[i % 2]`, `xs[len(xs) - 1]` and a nested `xs[ys[0]]` in a value
  position, inside a `when`/`while` condition and inside a `for` bound,
  lowered to `sx_lget`/`sx_idx` — `test-gen2-index-expr`,
  `test-gen2-index-mod`, `test-gen2-expr-lowering`
* **a parenthesised `for` source (2026-10-13):** `for c in (s)` and
  `for v in (xs)` strip whole-source parentheses on seed-min, gen2 and native —
  `test-for-paren`. A parenthesised *range* (`for i in (0..10)`) stays refused.
* **a concrete struct-typed `hold` annotation:** `hold p: Pt = Pt { 1, 2 }`
  is accepted and identity-checked by seed-min, gen2 and native; a scalar or a
  same-shaped but differently named struct is refused — `test-type-refusals`
* generics over numbers (`make NAME<T>`, `NAME<A, B>`), demand-driven generic
  bodies — `test-generics`, `test-native-generics`
* `use "file.sa"` splicing to depth 8 — `test-use`
* a mark & sweep collector with `gc()`, `gc_live()`, `gc_runs()` — `test-gc`,
  `docs/GC.md`
* the stdlib: seven modules, ~120 helpers — `test-stdlib`,
  `test-stdlib-modules`, `docs/STDLIB.md`

## What it refuses, with a diagnostic instead of wrong code

* a call other than `len()`, a comma, a quoted string, an empty index,
  unbalanced parentheses or a trailing operator inside `[ ]`
  (`make test-gen2-index-expr` and `test-gen2-expr-lowering` pin the refusals;
  `%`, `len()` and nested indexes are supported — see above)
* a global read inside an untyped `make` body
* direct `push(p.xs, v)`, whole-list `show p.xs`, and a whole list-valued field used as a condition on Gen2: these are explicit source refusals; use an aliased list variable, `len(p.xs)`, or `p.xs[i]` (`test-gen2-list-struct-fields`)
* a struct field annotation (`p: Pt` in a struct body): it used to register
  `Pt` as an extra field on all three backends; since 2026-10-13 all three
  refuse it (`test-type-refusals`). A literal after the colon (`k: 2`) is the
  old tolerated spelling and still parses as field `k` only.
* a *concrete* struct name as a generic type argument (`Box<Pt>`), an unknown
  name, an escaped type parameter, or the wrong argument count: refused on all
  three backends (`test-type-refusals`, `test-generic-struct-limits`). A
  nested instantiation (`Box<Box<num>>`) and `Box<list>` are **supported**
  since 2026-10-22 — `test-generic-structs-nested`
* a native-only construct on the portable path, and vice versa

The full list, with the backend that differs, is in `docs/STATUS.md` under
"Measured divergences".

## Inventory: what the compiler source itself uses (2026-10-17)

Audited 2026-10-17: main source plus `selfhost/modules/compiler_text.sa`
contain 18,713 lines, 644,798 bytes and 33 function definitions (one generic). Source non-use is not the
same as backend inability: the table distinguishes features not yet adopted
from features whose general forms remain unsupported.

| Feature | Used in `compiler_min.sa`? | gen2 supports it for user programs? |
|---|---|---|
| typed `make` signatures (`-> num/str/list`) | yes — every definition | yes (`test-typed-sig`) |
| `elif` / `else when` chains | yes (22 sites) | yes (`test-when`) |
| `&&` / `||` / `and` / `or` / `not` conditions | yes (hundreds of sites) | yes (`test-cond-string`, `test-logic-value`) |
| struct values and field chains | **yes, bounded adoption** — `CompilerPaths` stores input/output strings; fields drive reads, writes and include-directory scanning. Registry state remains delimited strings/lists; nested struct state is not adopted | yes (`test-struct2`, `test-nest`); actual compiler use pinned by `make gen3` |
| generic structs / generic functions | **yes, bounded real use** — generic `sxminimum<T>` bounds substring scanning; `CompilerSourceSize<num>` supplies the scan length | source-artifact and live-module tests run by `make gen3`; general user forms retain `test-generic-structs` / `test-generics` |
| string interpolation `${name}` | no; compiler implementation still uses explicit concat | **bounded gen2/gen3 support**, `test-string-interpolation`: string/number identifiers, escaping, imports and GC. The separate `test-stdlib-interpolation` remains a numeric lerp/smoothstep test, not string interpolation |
| struct-typed `hold` annotations | **yes** — `hold compiler_paths: CompilerPaths = ...` | yes on seed-min/gen2/native for concrete declarations (`test-type-refusals`) |
| list literals, `push`, `len`, index expressions | yes | yes |
| `use "..."` modules | **yes** — the live compiler imports compiler_text.sa (digits, slicing and generic bound helper) | actual bootstrap plus `make gen3` module fixture; still textual splice, not namespaces |
| file/process builtins (`read_file`, `write_file`, `run`) | yes | yes (`test-native-io` on native) |
| `gc()` / mark & sweep | the generated runtime, not the compiler's own code | yes (`test-gc`) |

## Self-host memory progress (2026-10-15)

The measured high-memory step is **gen1-min compiling compiler_min.sa into
gen2 C**, not necessarily gen2 compiling itself. Seed-generated functions used
to copy all string parameters on entry, even read-only source-text arguments.
The seed now borrows parameters that its conservative lexical scan finds
read-only, while retaining copies for potentially writable ones. An exact
allocation registry also replaces the unsafe builder magic-header probe.

Optional Linux `wait4` measurements, same 608,621-byte compiler source and
`cc -O2` before/after: **3,823,428 → 704,184 KiB peak RSS** (about 82% lower).
The intermediate borrow-only prototype was 638,512 KiB; the final safe registry
has overhead, so that smaller prototype number is not the shipped claim.
Generated gen2 C is byte-identical before/after. `make gen3` separately checks
that gen3/gen4 remain byte-identical. Logs: `ten-memory.log`,
`ten-memory-gen3.log`, and the final `ten-remaining-final-*.log` gates.

The later concrete-list-field work does change `compiler_min.sa`; `make doctor`
continues to verify the checked-in recovery/source path before each bootstrap
gate. No chunked/streaming compiler emission, complete seed GC, full-language
rewrite, or parallel Stage-2 path was added. Full-language self-host remains
**not claimed**. The source now uses a concrete struct and a struct-typed hold,
as well as a generic source-size struct and generic function from a live module.
This is still source adoption, not exhaustive language coverage. Namespaced modules are outside the bootstrap plan; nested generic
layouts remain refused *at this dated increment* (they landed 2026-10-22,
`test-generic-structs-nested`); Gen2 concrete list-field layout/lowering is
now gated by `test-gen2-list-struct-fields`.

## The Stage-2 host is not in this repository

Measured on 2026-10-21:

| Referenced by the old docs | Actual state |
|---|---|
| `make stage2` | no such target in the Makefile |
| `selfhost/bootstrap_full_language_selfhost.sh`, `selfhost/bootstrap_full_selfhost.sh` | no such files |
| `selfhost/stage2_template.c` | **deleted 2026-10-21** — it was a 93-byte `PLACEHOLDER` comment |
| `selfhost/stage2_src/` | **deleted 2026-10-21** — it was a README and an 11-byte `b64_0.txt` reading `PLACEHOLDER` |
| `selfhost/sxc_full.c`, `selfhost/sxc_full_minimal.c` | **deleted 2026-10-21** — 30-line toys that lowered only `hold NAME = <digits>` and `show` |
| `./selfhost/restore_stage2.sh` (and its `restore_sxc*.sh` siblings) | **deleted 2026-10-21** — a wrapper whose inputs were already gone, so it could only exit 1 |
| `./selfhost/sx` | **deleted 2026-10-21** — a CLI wrapper for the absent host |

Those files were scaffolding, not evidence. Keeping a placeholder byte-identical
to make a test true is a cost with no benefit, so `make test-doc-claims` now
asserts they stay gone as well as that no document advertises them.

There is therefore no C host that lowers "the full grammar". The way the
language grows is one increment at a time inside
`selfhost/compiler_min.sa` — Sayanox source, compiled by the C seed, gated by a
`make` target — and every increment is recorded in `docs/STATUS.md` with what it
does and does not claim.

## Editing the compiler source: two constraints found the hard way

1. **All `make` definitions belong in the leading block** (the leading function block of
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
   after the leading functions.

## Gated source expansion after PR #28 (2026-10-16)

`CompilerPaths` is a concrete two-string struct, initialized after command-line
argument resolution. Its fields now supply `read_file`, `write_file`, and the
input-directory scan used for relative includes. This replaces scalar reads in
real compiler work, rather than adding a dead feature demonstration. The seed,
gen2, gen3 and gen4 emit the concrete layout and field accesses.
`selfhost/test_compiler_source_features.sh`, invoked by `make gen3`, asserts
those properties in all four generated C artifacts and rechecks the fixed point.
The packed recovery source was regenerated and round-trip checked.

At this dated increment, remaining source-adoption work included generic
structs/functions, module directives, nested struct state and list-valued
struct state. The 2026-10-17 section supersedes that inventory and corrects
the unsupported string-interpolation claim. Existing
list/scalar/string code remains dominant. Remaining capability gaps at that
date included nested generic layouts, generic list-field specialization,
namespaced modules, and the explicit refusals above. Nested and list generic
arguments were implemented on 2026-10-22; the rest of the list stands. There is no exhaustive full-language compiler
source or full-language acceptance gate; **full-language self-host is not
claimed**. This increment does not change those limits or add a Stage-2 host.

No new peak-RSS reduction is claimed: no comparative memory measurement was
made for this change. The historical ~82% result above concerns the earlier
seed allocation work, not this source expansion.

Actual stdout/stderr logs are checked in under
[`gate-logs/2026-10-16-source-structs/`](gate-logs/2026-10-16-source-structs/):

* `doctor.log`: `DOCTOR-OK: core tool set is complete (not an audit of optional test utilities)`
* `true-selfhost.log`: `=== TRUE-SELFHOST-MIN-OK ===`
* `gen3.log`: `[OK] byte-identical gen3 == gen4`, compiler-source struct assertion, `=== GEN3-OK ===`
* `native-test.log`: `=== NATIVE-TEST-OK ===`
* `pack.log`: `[OK] pack-compiler-min: round-trip matches selfhost/compiler_min.sa`

The four requested gates ran in order with `&&`, all exiting zero. `make gen3`
was then rerun successfully after adding the artifact assertion. No Python was
used to edit, pack, build, or test this increment.

## Full-language completion attempt and measured blockers (2026-10-17)

**Not completed; no full-language claim.** The compiler now actually uses a
source module, generic function and generic struct, not just a separate feature
demo. `compiler_text.sa` owns the existing digit/slice functions and a generic
minimum used to bound every substring scan. `CompilerSourceSize<num>` supplies
the byte count used by compiler scans. Concrete typed path state is retained.
Main/module recovery blobs are regenerated separately, and deleting/restoring
the module was tested byte for byte without a network or interpreter.

`make gen3` now checks generic code/layout/field uses in actual bootstrap C and
has gen1-min/gen2/gen3 compile and run the **live source module** fixture with
strict C pointer/prototype checks and exact output. Gen3/gen4 remain identical.
This proves expanded source adoption, not full-language coverage.

The earlier `true-selfhost-full` target returned success for a subset build and
merely printed that full support was unfinished. It now **fails closed**:
subset tests and fixed point are necessary but insufficient; readiness checks
must pass, and a reviewed exhaustive acceptance specification is still missing.
The four established required gates do not invoke this intentionally failing
claim gate.

`make test-full-language-readiness` independently runs concrete closure probes
on gen2 **and gen3**. Actual results for this source:

| Proposed broader-language behavior | gen2 | gen3 |
|---|---|---|
| `show "hello ${name}"` substitutes a string variable | **passes**, identifier-only string/number holes; see below | same |
| named struct function argument and return | **passes**, bounded concrete named types; see below | same |
| `Size { bytes: len("abc") + 1 }` | source refusal / generated C fails compilation | same |
| `values[offset()]` with a numeric function | source refusal / generated C fails compilation | same |

These are **proposed closure requirements**, not retroactive promises of the
current bootstrap dialect. They are not an exhaustive language specification.
Excluded module aliases/namespaces are not silently declared supported.
(Nested/list generic arguments were on this list until 2026-10-22, when they
were implemented and gated instead — see
[`TYPES_ROADMAP.md`](TYPES_ROADMAP.md#nested-and-list-type-arguments-2026-10-22).) Even all four probes passing
would require a complete reviewed language contract before any full claim.
Readiness failures are expected and are not counted as successful coverage.

Initial logs: [2026-10-17 self-host readiness](gate-logs/2026-10-17-selfhost-readiness/)
record eight unmet checks before the struct-function implementation. The
[struct-function pass](gate-logs/2026-10-17-struct-functions/) reduced that to six.
Current logs: [string interpolation](gate-logs/2026-10-17-string-interpolation/).
The four hard gates passed again in order; current `readiness.log` still fails
with **four** unmet checks (two behaviors on two compilers). It is not a green
full-language gate.
No new peak-memory or complete-language claim is made.


## Concrete struct function types (bounded, 2026-10-17)

The Sayanox-written C emitter (gen2/gen3) now uses real by-value C struct
parameters, prototypes and returns. Its signature codec preserves the complete
concrete name (`uName;` per struct parameter, rather than one scalar character).
Function-local binding tables retain that same identity. Same-shaped structs
with different names are not interchangeable. Calls, nested calls, arity and
`give` are checked; unknown signature types no longer silently become `double`.
This is **not** an identity-function inlining workaround.

`make test-struct-functions` runs on both gen2 and gen3 and is also invoked by
`make gen3`. It checks multi-parameter selection, numeric field returns and
nested calls; scalar/wrong-name arguments and returns; arity; arithmetic on
struct results; unknown types; and explicit refusals of bounded unsupported
forms. GC fixtures exercise both a two-pointer register aggregate and a larger
nested aggregate across parameter passing, function return and repeated forced
collections, with string and numeric-list data used afterwards at `-O0` and
`-O2`. These are retention checks, not a new memory-improvement measurement.

Bounds remain important:

* Concrete named types only, not generic struct function annotations.
* Bind a struct literal or function result to a name before further use.
  Grouped struct-valued holds are explicitly refused; general expression-valued
  struct construction/fields have not been added.
* Field kinds are still inferred from literals in source order. A field-reading
  function needs a layout witness literal **before** its definition. The simple
  identity-copy readiness probe does not need a witness before the function.
  Unresolved field reads in this new checked path are source errors.
* Existing nested-literal initialization rules still apply; this change does
  not promise arbitrary struct reassignment or constructors.
* Seed-min and native struct **function signatures are not implemented by this
  pass**. Their scalar/list signatures and existing struct-variable support are
  unchanged. The compiler source itself does not adopt struct-typed functions,
  so the seed bootstrap contract is not widened.

Expression-valued struct fields, numeric calls in indexes and a reviewed
exhaustive language specification remain open. Interpolation is now supported
within the bounds below. Full-language
self-host is still **not complete**.


## Identifier string interpolation (bounded, 2026-10-17)

The Sayanox-written C backend (gen2/gen3) expands `"hello ${name}"` and
`"count=${n}"`. A hole must be a single identifier resolving to a string or
number in the current scope. Numbers use the existing `numstr`/`%g` formatting.
There are at most **16 holes per string literal**. Multiple/adjacent holes,
empty strings, quotes/backslashes, numeric loop updates and typed string
returns are tested. A single escaped dollar (`\${name}` in source) leaves the
literal `${name}` text; `\\${name}` emits a backslash then substitutes `name`.
`//` comments are not interpolated. Textual imports are spliced before expansion.

Expansion is implemented in `.sa`, using a collision-free private helper name,
existing concat lowering and checked scalar signatures. Generated C uses C11
`_Generic` for string/number dispatch and evaluates each identifier once.
Holes cannot contain calls or arbitrary expressions, so this does not introduce
an unspecified side-effect ordering contract. Unknown/out-of-scope names,
list/struct values, malformed holes, expression/call/field holes and a 17th
hole are refused with generated source diagnostics, not merely C type errors.
Bind a field or expression to a string/number name before interpolating it.

`make test-string-interpolation` runs both compilers at O0/O2 with C11 type
checks, output comparisons, import and struct-function integration, escaped-only
strings, forced-GC retention, the 16-hole boundary and ten refusal cases. It is
also run by `make gen3`. This does not add general expression-valued struct
fields, string lists, interpolated `use` paths or a format-specifier language.
Seed-min/native interpolation is **not implemented** in this pass. The compiler
source itself still uses concat rather than interpolation, preserving the seed
bootstrap dialect. No full-language or new memory-efficiency claim is made.
