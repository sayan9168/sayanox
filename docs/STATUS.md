# Status

Last updated: 2026-10-12

## Entry

```bash
make doctor             # -> DOCTOR-OK                log: docs/logs/make-doctor.log
make true-selfhost      # -> TRUE-SELFHOST-MIN-OK     log: docs/logs/make-true-selfhost-min.log
make gen3               # -> GEN3-OK (gen3 == gen4)   log: docs/logs/make-gen3.log
make native-test        # -> NATIVE-TEST-OK           log: docs/logs/make-native-test.log
```

The final four gate logs are in `docs/logs/` (2026-10-12). They were run on
this x86-64 Linux workspace, with the native compiler already built. Feature
claims below are bounded by the named tests, not a claim of full language
parity. Historical measurements are explicitly dated and have not all been
repeated in this pass. See the [current roadmap](#roadmap-done-vs-still-missing-per-backend-synced-2026-10-11).

GitHub Actions (`.github/workflows/ci.yml`) runs exactly these four targets —
`doctor`, `true-selfhost`, `gen3`, `native-test` — on a clean `ubuntu-latest`
checkout with no package install and no network: the runner's stock toolchain
is the minimal tool set `doctor` verifies.

## Minimal tool set (re-measured 2026-10-07)

Full audit, measurements and method: **[`DEPENDENCY.md`](../DEPENDENCY.md)**.

The bootstrap needs a host C toolchain and `make` — that is not "zero
dependencies" and is not claimed to be. What it does *not* need is any
Python, Node, Ruby, Perl or PHP on the bootstrap path. POSIX shell recipes
and tracked shell wrappers/probes are used; they are not Sayanox binaries.

| Tool | Needed for | Status |
|------|-----------|--------|
| `make` | the only entry point | **required** |
| C99 compiler (`cc`/`clang`/`gcc`) | building seed-min, gen1_min, gen2, gen3, native_aot | **required** |
| POSIX shell | recipe lines (verified under dash) | **required** |
| `grep` | asserting markers in *generated C* and expected error messages | **required** (proved: without it `true-selfhost` exits 2) |
| `cmp` | `gen3 == gen4` fixed point, seed-min/gen2 parity | **required** (proved: without it `gen3` exits 2) |
| `mkdir` | scratch test directory | **required** (proved: without it `seed-min-gen1` exits 127) |
| `base64`, `gzip`, `cat`, `tr`, `rm` | **only** the offline `compiler_min.sa` fallback | optional |

Measured external commands per target with a PATH logging shim (`as`/`ld` are
internal to the compiler):

| Target | External commands |
|--------|-------------------|
| `make doctor` | `make` |
| `make restore-compiler` (source present) | `make grep` |
| `make restore-compiler` (source missing) | `make grep cat tr base64 gzip rm` |
| `make true-selfhost` | `as cc cmp grep ld make mkdir` |
| `make gen3` | `as cc cmp ld make mkdir` |
| `make native-test` | `as cc grep ld make mkdir` |

Positive control for the three "required" assert tools, re-run 2026-10-08 on
this checkout with a `PATH` containing only `make cc as ld sh grep cmp mkdir`:
`make doctor`, `make true-selfhost` (which now runs `test-pkgs`, `test-stdlib`,
`test-builtin-names` and `test-stage2-demos` as well), `make gen3` and `make
native-test` all exit 0 with no `not found` line. No `curl`/`wget` and no
interpreter is ever executed — the bootstrap is fully offline. `make native-test` additionally needs an **x86-64
Linux** host, because `native_aot` writes x86-64 Linux ELF executables;
`true-selfhost` and `gen3` emit portable C.

Removed from the critical path in the earlier pass: `sed`, `awk`, `diff`, `wc`,
`cat`, `tr`, `base64`, `gzip` (the last five survive only in the optional
offline-restore fallback). The LSP probe used `mktemp`/`wc -c`/`tr -d`/`rm -rf`
until 2026-10-08; it now takes its work directory as an argument (created with
`mkdir`, left behind on purpose) and measures payloads with `${#payload}`, so
`make true-selfhost` needs no tool outside the list above. `selfhost/pack_compiler_min.sh` still uses
`bash`+`awk`+`mktemp`, but it is only reachable from the manual
`make pack-compiler` maintenance target, never from a bootstrap target.

`fix-seed` was ~20 lines of `awk` + `sed -i` rewriting the seed sources in
place. Every edit in it was dead: the `awk` guard's grep pattern
`ptok(k,(const char*)#ch` is a BRE where `r*` means "zero or more `r`", so it
could never match, and all six `sed -i` guards looked for pre-fix text that is
no longer in the checked-in sources. It is now `verify-seed`, a read-only
assertion (`fix-seed` remains as an alias). Test assertions moved off
`sed -n Np` onto a pure-shell `assert-out` helper that compares whole stdout
using only builtins, which is stricter than the per-line checks it replaced.

## Bootstrap memory (re-measured 2026-10-07, with the collector)

`selfhost/compiler_min.sa` is 400,647 bytes (391 KB; it was 244,058 bytes
earlier the same day — the growth is the generic pre-pass, the collector text
and the newer language checks). The
compiler flushes its `body` buffer into `obody` at ~1 KB (except while collecting
a function body), avoiding a flat O(n^2) accumulator that previously allocated
~2.5 GB and was killed on low-RAM hosts. A final string/identifier-aware C
literal pass flushes after at most 512 input bytes per chunk (before `.0`
expansion), bounding the temporary builder and avoiding a full-prefix copy per
character.
Measured 2026-10-07 after the mark & sweep collector landed (peak RSS from
`wait4` `ru_maxrss`):

| Step | Peak RSS (with GC) | (pre-GC, same day) |
|------|--------------------|--------------------|
| `seed-min` compiling `compiler_min.sa` -> `gen1_min.c` | 1.9 MB | 1.8 MB |
| `gen1_min` compiling `compiler_min.sa` -> `gen2.c` | 100.6 MB | 57.9 MB |
| `gen2` compiling `compiler_min.sa` -> `gen3.c` | 32.6 MB | 218.6 MB |

`gen2`'s own peak fell 6.7x: it is built by `gen1_min`, emits the collector
into itself, and now frees the strings it allocates while compiling.
`gen1_min` is built by the malloc-only seed and reads a bigger source than
before, so its peak grew; it runs once per bootstrap and is not on the
memory-critical path.

On this checkout `gen1_min` and `gen2` each need ~20 s to compile
`compiler_min.sa`, `make gen2` ~35 s, `make true-selfhost` ~2 min,
`make gen3` ~1 min and `make native-test` ~3 s. `gen2` produces byte-identical
output under `ulimit -v 65536` (a 64 MB address-space cap, down from 400 MB
before the collector), and `make gen3` reaches its fixed point
(`gen3 == gen4`) without being killed.

## Language roadmap (2026-10-11)

Done means the feature is implemented and a `make` target that runs in a gate
(or is part of one) checks it. Missing means not implemented on that backend.
Deferred means it is too large for the current pass; the reason is given.
Four gates on this checkout: `DOCTOR-OK`, `TRUE-SELFHOST-MIN-OK`, `GEN3-OK`,
`NATIVE-TEST-OK`.

The authoritative backend/gate/missing-work table is the roadmap at the end
of this document. Seed Stage-2 was extended this pass; native logic values,
generics and function-local slots already existed and were re-tested.

## Coverage (pure-min dialect)

| Feature | seed-min | gen2 (compiler_min) | native (native_aot) |
|---------|----------|---------------------|---------------------|
| `hold` / `show` (num, str) | yes | yes | yes |
| `when` / `while`, `== != < <= > >=` | yes | yes | yes |
| `otherwise` after `}` | yes | yes | yes |
| `else` alias after `}` (true *and* false branch) | yes | yes | yes (false branch fixed 2026-10-06) |
| `+ -` on numbers, string `+` (concat) | yes | yes | yes |
| string `+` number (`"a" + 1`) | error | error (was silently wrong: `s + n` printed the *name* `n`) | error (2026-10-08: matched the shared subset; the number used to be joined with `%g`) |
| `*` | yes | yes | yes |
| `/` | yes (10/4 = 2.5) | yes (2.5) | yes (2.5; IEEE double, 2026-10-07) |
| `/` by zero | `inf` / `-nan` | `inf` / `-nan` | `inf` / `-nan` |
| `%` modulo (truncates both sides, `-7 % 3` = -1) | yes | yes | yes |
| `%` by zero | exit 1, `division by zero` | exit 1, `division by zero` | exit 1, `division by zero` |
| chained ops (`a + b + c`; `* / %` bind tighter, left-assoc) | yes | yes | yes |
| `%` inside `when`/`while` conditions | yes | yes | yes |
| `make` / `give` (top level, numeric) | yes | yes | yes (enabled 2026-10-06; `hold` inside a body is a clear error) |
| recursion | yes | yes | yes (`fac(5)` = 120, `fib(20)` = 6765, mutual recursion) |
| lists: `[..]`, `xs[i]`, `len` | yes | yes | yes |
| `hold xs = push(xs, v)` (expression form) | yes | yes | yes |
| bare `push(xs, v)` statement | yes (2026-10-07) | yes (2026-10-07) | yes |
| bare call statement (`write_file(p, s)` on its own line) | error: `unknown statement` | error: `unknown statement` | error: `unknown statement` (2026-10-08; `push(xs, v)` is the only call statement, as in the other two) |
| structs: number fields, `p.x`, `Point { 1, 2 }` | yes | yes | yes |
| structs: string fields (`name: "ada"`) | yes | yes | yes |
| structs: nested 2 and 3 deep (`Line { a: Point { 1, 2 } }`, `l.a.x`), typed copy `hold m = l.a` | yes | yes | yes (verified with `make native-test`) |
| copy of a doubly nested field (`hold p2 = r.q.p`) | yes (fixed 2026-10-06) | yes | yes |
| string builtins: `concat len chr` | yes | yes | yes |
| string builtins: `string_eq` | yes | yes | yes (numeric result) |
| string builtins: `sx_index` and `s[i]` | yes | yes | yes (fixed 2026-10-06) |
| builtins: `read_file write_file arg arg_count` | yes | yes | yes (fixed 2026-10-07: `arg_count()` counts argv[0], `arg(0)` is the binary path, `write_file` truncates and returns 1, a missing file reads as `""`) |
| `use "file.sa"` (modules) | yes | yes | yes (spliced before parsing; missing file / unquoted path are clear errors) |
| base `OP` operand on either side (`10 % 3`, `p.x + p.y`, `xs[1] + 5`, `len(xs) + 1`, `3 * xs[0]`, `p.x * p.x`) | yes | yes | yes (right of `* / %` fixed 2026-10-06) |
| parenthesized base expression (`(a + 3) * 4`) | yes (20) | yes (20; 2026-10-07) | yes (20) |
| fractional literal (`hold x = 2.5`; `2.` and `1.2.3` are errors) | yes (2026-10-07) | yes (2026-10-07; used to print 2) | yes (2026-10-07) |
| integer-only arithmetic uses double constants (`100000 * 100000` = `1e+10`) | yes (2026-10-07) | yes (2026-10-07) | yes |
| list literal with 10+ elements | yes | yes (was invalid C) | yes |
| whole-list copy `hold ys = xs` | yes | yes (2026-10-07) | yes |
| a builtin word used as a variable (`hold index = 1`, then `sx_index(s, index)`) | yes | yes (2026-10-08: the argument-text rewriter only maps a builtin that is really *called*; it used to emit `sx_idx(s, sx_idx)`) | yes (never had the bug) |

## Measured divergences (re-measured 2026-10-08)

The two native-only *statement/type* extensions that used to be listed here are
gone: a bare call statement other than `push(xs, v)`, and `string + number`,
are now rejected by native with the same wording as seed-min and gen2
(`make test-native-num`, `make test-push-stmt`). The seed-min and gen2
compilers agree on the whole shared dialect; 64 repository `.sa` programs have
also been compared across all three backends for byte-identical stdout.

What is still different, and honest about it:

| Area | seed-min | gen2 | native |
|------|----------|------|--------|
| `hold` inside a `make` body | accepted | accepted (a local slot) | accepted since 2026-10-11 (a local slot in the call's own frame; the collector scans it) |
| collector builtins `gc()` / `gc_live()` / `gc_runs()` | error: no collector in the seed runtime | yes (mark & sweep) | yes (native mark & sweep, see `GC.md`; corrected 2026-10-10 — this row used to say `undefined variable 'gc'`) |
| memory under an address-space cap (measured 2026-10-13, `make test-seed-gc`) | no collector: a 200k churn that retains nothing and a 2000-step accumulation both run inside a 4 MiB cap; an 8388608-byte live set exits 1 with `sx: out of memory` | mark & sweep, first collection at 8 MiB of managed heap: the same churn needs a 64 MiB cap and fails at 16 MiB with `sx: out of memory` (was a segfault) | mark & sweep at every statement boundary past a debt threshold: the same churn runs inside a 4 MiB cap (`test-native-mem`) |
| Stage-2 | boolean literals/logic, elif, while break/continue, named/literal string-list for and numeric ranges outside make | broader Stage-2 including literals/calls/ranges and typed functions | broader Stage-2 plus logic values and kind generics |
| diagnostic wording | own text (`seed_min: ...`) | own text (`min: ...` / `#error` line) | own text (`native_aot: ...`) |
| host and memory | any C host, malloc-based, no collector (builder-backed strings plus a freeing assignment wrapper — see `GC.md` §2) | any C host, mark & sweep | x86-64 Linux only; own heap (first-fit + bump) with a mark & sweep collector (corrected 2026-10-10; was "bump-allocated, never freed") |

The full seed `sxc_seed` is deliberately not a column in that table: it is not
on the bootstrap path (`seed-min -> gen1_min -> gen2` is), and until 2026-10-13
it could not compile a comparison at all. Measured now, with `make
test-seed-gc`:

* its lexer recorded a single-character operator token's text as the
  *stringized char literal*, quotes included (`'*'`, `'<'`), so `emit_expr`
  matched none of its operator spellings and dropped the operator — `show 2 * 3`
  became `sx_show(((double)2LL),((double)3LL)))`, which does not compile.
  Arithmetic, comparisons and `while`/`when` conditions were all broken. Fixed
  by building the token text from the character value; the fixture
  `selfhost/seed_gc_ops.sa` now prints the same nine values on the full seed,
  seed-min and gen2;
* `gc()` exists but is a documented no-op returning `0`, `gc_live()` and
  `gc_runs()` do not exist, and `SX_GC_DEBUG=1` shows the reference counts are
  not releasing in loops: 6000 objects are still alive at exit after 2000
  iterations that retain nothing (`GC.md` §2, "The two seeds, measured");
* its object table is a static 2097152-entry array, so a 4 MiB cap cannot even
  start it and its measurements run under a 64 MiB cap;
* a program using `%` needs `-lm` *after* the sources on the link line
  (`sx_modv` calls `fmod`);
* it prints a large integer as `8388608` where seed-min, gen2 and native print
  `8.38861e+06`. That formatting difference is pinned, not fixed: the full seed
  is not a release backend.

Two numeric mismatches from the prior audit are fixed and covered by
`make test-float` and `make test-native-num`:

* Integer-only expressions now use double literals in generated C. This covers
  nested arithmetic, conditions, function arguments and `give` expressions;
  `show 100000 * 100000` prints `1e+10` on seed-min, gen2 and native rather
  than overflowing as a 32-bit C `int`.
* `%` now checks the truncated divisor before taking the remainder. Every
  backend exits non-zero with a clear `division by zero` diagnostic.

In seed-min, integer tokens are emitted with a `.0` suffix. gen2 applies a
string/identifier-aware integer-token normalization to generated function and
main code, flushing after at most 512 input bytes per chunk (before `.0`
expansion). Runtime code, strings and identifiers are unchanged. Native
arithmetic already uses IEEE doubles. Generated-C modulo expressions use the
same `sx_mod` helper in seed-min and gen2; native checks for zero before signed
remainder.

The documented dialect (see `docs/SYNTAX.md`, `docs/CHEATSHEET.md`) shows
`push(xs, 4)` as a statement; all three backends accept it, and
`hold xs = push(xs, v)` works everywhere.

Struct field types come from the literals that fill them: a field is `double`
or `char *`, the first literal that mentions it decides, and a conflicting
later literal is a hard error. `hold s = u.name` is typed as a string.

### gen2 gaps found on 2026-10-08: all fixed

Reproduced on gen2 while adding the Stage-2 slice, then fixed and pinned by
`make test-gen2-gaps` (part of `true-selfhost-min`):

* **`len(` in a range bound.** `for i in 0..len(xs)` (a declared list,
  `sx_llen`) and `for j in 0..len(s)` (a string, `sx_len`) compile and run.
  Before, the C called an undefined `len` and failed at link time.
* **String `==` and `!=`.** `A == B` and `A != B` compile to `sx_eq` (strcmp)
  when A is a declared string and B is a declared string or a quoted literal.
  Before, they compared addresses, so two equal strings built with `concat`
  compared unequal. The rewrite is narrow on purpose: other operand shapes are
  copied unchanged.
* **`else when`, `else if` and `otherwise when`.** These are chains like
  `elif`. Before, `} else if COND {` also failed (the plain `else` was emitted
  twice), so the documented `else if` form did not work on gen2 either.
  `} elif COND {` was always fine.
* **String ordering.** `s < t` and the other orderings on strings were
  pointer compares, which gave arbitrary answers. Now `sx_cmp` (strcmp) on
  gen2 and `strcmp` on seed-min, for declared strings and quoted literals on
  either side (`make test-gen2-gaps`). Native orderings were added 2026-10-10 (`make test-native-strord`).
* **`%` inside a builtin-call argument.** `chr(48 + m % 10)`,
  `concat("x", chr(m % 10))` and `chr(48 + x * m % 10)` now compile. Each `%`
  becomes `sx_mod(L, R)`, using the same operand rule as the condition
  rewrite: L is the `* / %` chain to its left (`x * m % 10` is
  `(x * m) % 10`), R is the next atom. `%` inside a string literal is text.
  Seed-min and gen2 print the same output (`make test-gen2-gaps`).

Design notes (documented behaviour, not gaps):

* **Flat scope.** Pure-min scoping is flat: a `hold x = ...` inside a `when`
  or `while` body assigns to the outer `x` and does not shadow it. This is the
  rule the compiler is written against (see the `for` notes in
  `selfhost/compiler_min.sa`). Do not rely on shadowing.
* **String ordering and equality (2026-10-08).** `<`, `<=`, `>`, `>=`, `==`
  and `!=` between two strings compare by content (`strcmp`) on gen2 and on
  seed-min. A string compared with a number, list or struct is an error on
  seed-min. Native implements `==`/`!=` (`string_eq`) and, since 2026-10-10, the orderings
  (unsigned-byte strcmp, `make test-native-strord`). Recorded as closed below.

### Divergences measured on 2026-10-13 (open, not fixed)

Found while growing `stdlib/` (item: stdlib growth) and while finishing the
seed `for` forms. Each one was reproduced with a minimal program; none is
papered over in the library, and each is pinned by a test or documented here.

* **FIXED 2026-10-13: gen2 index expressions.** `xs[i - 1]` and `xs[1 + 1]`
  used to make gen2 emit
  `#error sayanox-min: unsupported index expression (number or name only)`, and
  an index inside a `when`/`while` condition or a `for` bound was copied
  verbatim so the C subscripted an `sx_list` struct with a double
  (`array subscript is not an integer`). An index is now a numeric expression
  in all three positions, on all three backends (`make test-gen2-index-expr`,
  39 values). **Fixed again later the same day:** `len(NAME)` and a nested
  `NAME[IDX]` inside `[ ]` now lower too, in a value, in a chain operand, in a
  condition, in a `for` bound and inside a typed body (helper `idx_lower`,
  `make test-gen2-expr-lowering`, 18 values). What gen2 still refuses inside
  `[ ]`, each with a clear diagnostic and a `#error` rather than invalid C:
  `%`, a call other than `len()`, a comma, a quoted string, an empty index,
  unbalanced parentheses or brackets, and an expression that ends with an
  operator. The workaround is `hold n = <expr>` then `xs[n]`; seed-min and
  native accept a call other than `len()` inside an index, so that one row
  stays open as a narrower divergence.
* **FIXED 2026-10-13: gen2 `give` with a direct string `+` chain.** Inside a
  function body, `give "hi " + name` and `give "a" + "b"` used to emit invalid C
  (`invalid operands to binary + (have 'char *' and 'char *')`), so the
  generated file failed to compile, while the same chain in a `hold` worked.
  The expression rewriter behind `give`, `when`/`while` conditions and
  parenthesized expressions now joins two strings through `sx_cat` and nests a
  chain, exactly as the value-position parser already did
  (`make test-gen2-expr-lowering`, 11 values identical on seed-min, gen2 and
  native). A `+` with exactly one string side is refused with the value
  parser's own sentence, and so is `%` with a string operand — a `min:`
  diagnostic plus a `#error`, never C that only fails at cc time. A struct
  string field and a user-function call are not classified as strings there
  yet, so `give "n=" + p.name` is refused rather than mis-compiled; bind it
  with `hold` first.
* **A negative index and a unary sign.** `xs[-1]` wraps to the last element on
  seed-min and gen2 (`sx_lget`/`sx_idx` add the length when the index is
  negative). native refuses a unary sign in an index at compile time
  (`native_aot: bad expression`) and reports `list index out of range` at run
  time for `xs[0 - 1]`. `make test-gen2-index-expr` pins seed-min/gen2
  agreement and asserts that native still refuses, so the difference cannot
  drift silently.
* **A `make` in the middle of `compiler_min.sa` is not a definition.** The
  self-hosted compiler source keeps all 16 of its `make` helpers in the leading
  block (lines 1-841) before any top-level statement. Adding `raw_index` after
  ~2400 lines of top-level code made gen1_min emit a signature whose parameter
  annotations had been split into extra parameters
  (`raw_index(double source, double str, double from, double num, ...)`), so
  gen2.c did not compile. Moving the helper into the leading block fixed it.
  Recorded here because it is a constraint on editing the compiler source, not
  a property of user programs: a user program with a `make` after top-level
  statements compiles fine on all three backends.
* **A global read inside an untyped `make` body.** seed-min and gen2 refuse it
  with their own clear diagnostics; `native_aot` still prints the value,
  because its scope model differs. Hoisting top-level variables out of
  `main()` so that all three agree was rejected as a design direction: the
  compilers prefer an explicit refusal to codegen that quietly reads the wrong
  storage. `for` sources inside untyped `make` bodies were completed instead
  (`test-seed-for-untyped`).

## Verified behaviour

```bash
make true-selfhost   # seed-min -> gen1_min -> gen2, then every feature test on gen2
make gen3            # gen3 == gen4 byte-identical + feature tests on gen3
make native-test     # real x86-64: core control flow, lists, structs, modules,
                     # recursion, double/large-constant math, %0 diagnostics,
                     # file and argv builtins
make seed-min        # seed-min: hold/show/while/struct/list/fn/%/else/use
```

Program:

```sayanox
hold a = 10
show a % 3
when a > 5 { show 1 } else { show 0 }
```

prints `1` then `1` via gen2 (and via seed-min and via native).

Chain and struct examples verified by `make test-chain`, `make test-user` and
`make test-nest`:

```sayanox
hold s = "a"
show s + "b" + "!"          # ab!

struct Point { name, x }
struct Line  { a, b }
hold l = Line { a: Point { name: "p1", x: 1 }, b: Point { name: "p2", x: 2 } }
show l.a.name               # p1     (seed-min)
show l.a.x                  # 1      (seed-min)
```

## Sayanox-written tooling milestone

`tools/sxfmt.sa` is a working, conservative formatter written in Sayanox and
compiled by the maintained gen2 compiler. `make sxfmt` builds it; `make test-sxfmt`
checks nested-block indentation, braces inside strings/comments, trailing
whitespace removal, final-newline normalization and idempotence. It preserves
tokens and is not yet a syntax-aware formatter.

`tools/sxpkg.sa` implements local `init`, `add`, `list`, `remove`, `seed`,
`search`, `info`, `verify` and `sum`; the shell entrypoint delegates these
commands to it. `make sxpkg` builds the program and `make test-sxpkg` checks
the command path. Offline integrity: `pkg.meta` carries a `sum=` content check
that `verify` compares against the project's registry copy
([`REGISTRY.md`](REGISTRY.md)). It is not a security signature.
Sync/install/publish/fetch and package-directory operations remain in shell.

The language server is a full Sayanox program (`tools/sayanox_lsp.sa`, built
by gen2 and covered by `make test-lsp`); `tools/sayanox-lsp.sh` remains as a
dependency-free shell fallback. These are migration slices, not an "all tools
are Sayanox" claim: online package operations, the seed and the native backend
still use shell/C infrastructure. See
[`ONLY_SAYANOX.md`](ONLY_SAYANOX.md) and
[`SELF_HOSTING_ROADMAP.md`](SELF_HOSTING_ROADMAP.md).

## Honest boundaries

* **Modules** (`use "file.sa"`): spliced before parsing, depth <= 8, only at a
  real statement start (never inside strings or `//` comments). A missing file
  is a hard error: gen2 emits `#error` into the generated C (so the C compile
  fails loudly); seed-min prints to stderr and exits non-zero. An unquoted
  path (`use other.sa`) is reported the same way instead of being compiled as
  garbage identifiers. Paths resolve against the current directory first, then
  next to the input file.
* **Structs** are typed from literals (see above); a missing field defaults to
  `""`/`0` in seed-min, while gen2 requires every field of a literal to be
  present. **Nested structs** (`a: Point { 1, 2 }`, chains such as `l.a.x`)
  work in **all three backends** (verified with output parity in
  `make test-nest` for seed-min/gen2 and in `make native-test` for native,
  including three levels deep). Rules, enforced by all three:
  the nested struct must be declared before the struct that nests it (so
  typedefs stay dependency-ordered), a struct-valued field must be filled in
  every literal, a struct value can be copied with a typed declaration
  (`hold m = l.b`, `hold r = q`), and a chain through a field that has no
  struct type is a hard error. A list inside a struct field and a struct
  value inside a list are hard errors in both compilers; `show` of a struct
  value is a hard error in gen2 and in native. Copying a *doubly* nested
  field (`hold p2 = r.q.p`) now works in **all three backends** (seed-min's
  first collect pass used to walk the chain before the literal scan had
  typed its links and died with a misleading "has no struct type"; fixed
  2026-10-06, pinned by `make test-nest` and `make native-test`), as does
  copying one level (`hold m = l.a`).
* **Parenthesized expressions** (`show (a + 3) * 4`, nested parens, parens in
  `hold`, `give` and conditions) work in all three backends since 2026-10-07
  (`make test-parens`, and native output parity in `make native-test`).
  Parentheses around a non-numeric value and unbalanced parentheses are clear
  errors in gen2.
* **Numbers are IEEE doubles** in all three backends: integer and fractional
  literals (`2.5`, `0.75`; `2.` and `1.2.3` are clear errors), `/` is true
  division (`10 / 4` = 2.5, `1 / 0` = `inf`), `%` truncates both operands to
  integers first, and `show` prints like C's `printf("%g")` (`0.333333`,
  `1e+10`). Constant-only arithmetic, conditions, function arguments and
  returns also use double literals, avoiding C's 32-bit integer overflow.
  `% 0` exits with the same `division by zero` diagnostic in all three.
* **Strings and numbers do not mix in pure-min**: `+` joins two strings or adds
  two numbers. seed-min and gen2 reject `"a" + 1`, `1 + "a"` and `-`/`*`/`/`/`%`
  on strings with a clear error (gen2 used to paste the variable's *name* into
  the string: `s + n` printed `an`). native used to accept the mix and format
  the number with `%g`; since 2026-10-08 it rejects it with the same wording,
  so all three backends implement one subset — use `concat(s, n)` to build
  a string from a number.
* **Statements**: a statement starts with `hold show when while make give
  struct use` (plus `otherwise`/`else` after a `}`) or is a bare
  `push(xs, v)`. Anything else — a misspelled keyword, a bare
  `write_file(...)` call — is an `unknown statement` error in seed-min,
  gen2 (gen2 used to drop such lines silently or emit invalid C) and, since
  2026-10-08, native (it used to run any bare builtin call).
  Seed-min now also supports `elif`, `break`/`continue`, boolean word
  operators/literals, and `for` over named list/string sources or literals outside make.
  Unsupported iteration forms receive explicit diagnostics (see roadmap).
* **String iteration** binds a one-byte string per iteration. Empty strings,
  nesting, repeated counter names across sequential loops and UTF-8 byte
  iteration are tested on seed-min and gen2 by `make test-for-str`; native
  also supports string iteration. `"é"` is two iterations, not one codepoint.
  The source variable is re-read each iteration, including after rebinding.
* **Collector builtins** (`gc()`, `gc_live()`, `gc_runs()`) are gen2/gen1_min
  and native (mark & sweep, corrected 2026-10-10): the seed runtime has no
  collector. They are ordinary expression
  calls, so `hold freed = gc()` works; a *bare* `gc` statement is still an
  unknown statement.
* **Lists** are `double`-only, one type per program; `push` returns the list
  and also works as a bare statement. `hold ys = xs` copies the list
  reference. A string, list or struct as a list element is a clear error in
  every backend, and `+`/`-` on a list is a clear error (never pointer
  arithmetic in the emitted C).
* **Functions**: top level only, numeric params/return, recursion works in
  all three backends (native function codegen was fixed and enabled
  2026-10-06: up to 6 numeric params, forward references, mutual recursion,
  zero-arg calls, and calls as arguments of other calls). Calling a user
  function is supported in `hold` RHS, `show` and `give`. Native function
  locals use per-call stack frames; recursive local holds are covered by
  `test-native-locals`. Seed-min and gen2 emit C locals. Typed string/list
  signatures and generics are now supported by seed-min as well as gen2/native,
  within the documented per-backend subsets.
* **Statements are newline-terminated**: write one statement per line. In
  particular `give 0 }` on one line swallows the `}` into the returned
  expression; the compiler now reports that as an error instead of letting it
  become invalid C.
* **`hold`/`show`** accept a chain of binary operands — number, name, field
  (`p.x + p.y`), index (`xs[1]`), call (`len(xs)`) — with the usual precedence
  (`* / %` bind tighter than `+ -`) and left-associativity; `hold u = s + t +
  "!"` concatenates strings, and `%` lowers through the checked `sx_mod`
  helper in the C backends.
* **`use` paths** resolve against the current directory first, then next to
  the input file, so `./selfhost/gen2 dir/main.sa out.c` finds `dir/lib.sa`.
* **Conditions** in `when`/`while` are copied as C text with `%` lowered to
  `sx_mod(a, b)`, so `while a % 10 > 0` uses the same truncation and zero-divisor
  behavior as ordinary expressions; the remaining operators must be valid C
  (`*`, `/` and comparisons are).
* **native_aot** covers `hold/show/when/else/while`, IEEE double numbers
  (fractional literals, true `/`, `%g` output identical to seed-min),
  `+ - * / %`
  (postfix operands on either side of any operator: `p.x * p.x`, `3 * xs[0]`;
  `/` and `%` stay left-associative), comparisons, `show "str"`, string
  `concat`/`len`/`chr`/`string_eq`/`sx_index` and `s[i]` (the index builtin
  used to lose its index inside its own strlen call; fixed 2026-10-06),
  literal lists (`[1, 2]`, `xs[i]`, `len`, `push` — the list grows in place,
  out-of-range indexes die), structs including nested ones
  (`Line { a: Point { 1, 2 } }`, `l.a.x` chains, typed copies of a struct
  field, doubly nested copies `hold p2 = t.q.p`), `use "file.sa"` module
  splice (before parsing, depth <= 8, resolved against the input file's
  directory then the cwd; missing file and unquoted path are clear errors;
  the splice buffer grows, so a large library file cannot overflow it), and
  functions: top-level `make`/`give`, up to 6 numeric params, recursion
  (`fib(20)` = 6765, `fac(20)` exact), forward references, mutual recursion,
  zero-arg calls, global assignment from a body, and calls/builtins as
  arguments of other calls — every staged argument and every index base
  rides on the machine stack, so a nested or recursive call cannot clobber
  them. Function codegen was enabled 2026-10-06 after fixing the parameter
  spills (params 1/3/4 spilled rbx/r13/r9 instead of rdi/rdx/rcx), the frame
  size (a fixed 32-byte frame let the first push overwrite params 5-6) and
  argument staging; `make native-test` pins all of it.
  Every distinct variable name gets its own data slot (two names sharing a
  first letter no longer share storage) and an undeclared name is a hard
  error instead of reading as 0. Rejected with a clear error: `hold` inside
  a `make` body, `give` outside a function, `make` inside a block, a wrong
  argument count, a non-numeric argument or `give`, field access on a
  non-struct, a later-declared nested struct, a list inside a struct field
  and `show` of a struct value.
  The file and argument builtins (`read_file`, `write_file`, `arg`,
  `arg_count`) work and match seed-min/gen2 (`make test-native-io`, including
  a 160 KiB round trip). The statement and type subset is the same as seed-min
  and gen2: string + number and bare non-`push` call statements are rejected
  (`make test-native-num`). The remaining differences are the ones in the
  divergence table (the seed Stage-2/type limits and platform differences). Native output is x86-64 Linux only. The runtime
  is a flat BSS data area plus a **real mark & sweep collector** over lazily
  `mmap`ped chunks (malloc/memcpy/copy semantics verified by probe programs).
  Blocks carry a 32-byte header (size|FREE, magic, mark/next, kind);
  `r_malloc` is first-fit over a free list and then bumps; `r_gc` traces from
  a precise root table (every string/list/struct global plus the literal
  scratch, filled in after codegen) *and* conservatively from `[rsp,
  stktop)`, frees what it cannot reach, coalesces adjacent runs, rebuilds the
  free list and `munmap`s chunks a sweep emptied completely. Collections are
  triggered at statement boundaries once the bytes allocated since the last
  one pass `max(2 * live, 64 KiB)`. `gc()`, `gc_live()` and `gc_runs()` are
  therefore **real on native**, not compatibility no-ops: `gc()` collects and
  returns the bytes reclaimed.
  `make test-native-mem` (part of `native-test`) pins the behaviour: a
  262144-byte string (larger than one 64 KiB chunk), a 100000-element `push`
  loop and a 20000-iteration `concat` loop keep every value and index correct;
  a 200000-iteration churn loop (~8 MB allocated, nothing retained) **finishes
  inside a 4 MiB `ulimit -v` cap** running 200+ collections, and strings,
  list elements and struct fields still read back correctly after 30000
  allocating iterations; a program that genuinely retains 8 MiB still dies with
  the documented `out of memory` diagnostic, stdout written before the failure
  is kept, and the status is non-zero rather than memory being corrupted.
  The collector is not compacting and the conservative half of the root set
  can retain garbage (a stale stack word keeps a block alive); see
  [`GC.md`](GC.md).
* **Stage-2 demo programs**: `selfhost/minimal_lexer.sa`,
  `selfhost/stage2_functions.sa` and `selfhost/stage2_variables.sa` are
  written in the pure-min dialect and are compiled and run by both seed-min
  and gen2 with byte-identical stdout (`make test-stage2-demos`). They
  illustrate the Stage-2 *contract* (explicit slots, function contracts) —
  they are not the full Stage-2 language.
* Still not part of pure-min: modules with namespacing/aliases — not claimed
  anywhere (see "Out of scope" below). The GC is no longer on that list:
  gen2-compiled programs link the collector in [`GC.md`](GC.md). Generics are
  no longer on it either: `make NAME<T>(a: T, b: T) -> T` monomorphises one
  copy per call-site kind (`make test-generics`, [`SYNTAX.md`](SYNTAX.md)).

## Feature tests

| Target | Covers |
|--------|--------|
| `make test-reassign` / `test-while` / `test-when` | core statements |
| `make test-mod` | `%` lowering + `else` alias |
| `make test-chain` | chained `+ - * / %`, precedence, string `+` (seed-min and gen2 agree) |
| `make test-condmod` | checked `%` lowering inside `when`/`while` conditions |
| `make test-struct2` | named fields, two structs, `p.x + p.y` |
| `make test-user` | struct string fields (`User name/age`); mismatches are hard errors; a string chain that starts at a struct field links and prints the same in seed-min, gen2 and native (gen2 used to omit `sx_cat`) |
| `make test-nest` | nested structs in seed-min and gen2 (output parity, 3-level deep, ordered struct-typed fields, typed copies including the doubly nested `hold p2 = t.q.p`); clear errors for forward decls, list fields, bad chains, show-of-struct |
| `make test-list2` | literal, index, `len`, `push` |
| `make test-use` | splice, nested depth 2, missing-file error |
| `make test-fn2` | params, call in `show`, recursion (`fac 5 = 120`) |
| `make test-boot` | gen2 compiles `compiler_boot.sa` and the result runs |
| `make test-parity` | seed-min and gen2 agree on one program using the whole shared dialect |
| `make seed-min` / `test-struct` / `test-list` / `test-fn` | same features on the C seed |
| `make test-prec` | precedence (`a + 3 * 4` = 14 in seed-min and gen2) |
| `make test-float` | fractional literals, true division, double constant arithmetic (including large products in conditions and functions), and deterministic `% 0` errors in seed-min and gen2; malformed numbers are rejected outside strings/comments |
| `make test-parens` | parenthesized expressions in seed-min and gen2 (`(a + 3) * 4` = 20, nesting, unary minus, parens in conditions and `give`); non-numeric and unbalanced parens are clear errors |
| `make test-push-stmt` | bare `push(xs, v)` in seed-min and gen2; push onto a non-list, unknown statements, string + number, number + string, string `-` and `*`, a string list element, 10+ element list literals, struct-in-list, `hold ys = xs`, list arithmetic — all clear errors or correct output |
| `make test-builtin-names` | a variable named `index`/`len`/`arg` keeps its value while `len(s)`, `chr(65)` and a nested `sx_index(s, index)` still map to the runtime helpers, on seed-min and gen2 (gen2 used to emit `sx_idx(s, sx_idx)`, which is also what made `tools/sxpkg.sa`'s `search` never match) |
| `make test-native-num` (part of `native-test`) | native doubles: `test-float`/`test-parens`/`test-push-stmt` programs give the same output as seed-min and gen2; large integer-only arithmetic, `%` truncation and `% 0` diagnostic, `%g` formatting, IEEE `/ 0`, struct-field string chains; string + number, number + string and bare non-`push` call statements are rejected with the shared wording |
| `make test-lsp` | the Sayanox language server in five live JSON-RPC sessions (probe written with shell builtins + `mkdir` only), 29 asserted facts: initialize/serverInfo, didOpen + publishDiagnostics, SX1001/SX1002/SX1003/SX1005 diagnostics, documentSymbol (function + variable), completion (builtin names survive in string literals), hover, definition, a didChange that clears the diagnostics, a closed document answering empty, the four-slot eviction cap, `references` across the open documents with and without `includeDeclaration` plus a non-word position answering `[]`, `workspace/symbol` with a query and with an empty one, and `textDocument/formatting` on a badly indented buffer (whole-buffer edit, two-space-per-level indent, trailing whitespace stripped) and on an already formatted one (`[]`) |
| `make test-generics` | two legs. (a) single type parameter: `make NAME<T> ... -> T` — 14 lines of a program mixing `pickb`/`twice`/`quad` over num, str and list print identically under gen2 and gen1_min; each `NAME__n/s/l` appears exactly once, every call sees a prototype, an unused generic emits nothing. (b) **multi-parameter**: `pair<A, B> -> A`, `swap<A, B> -> B`, `three<A, B, C> -> C` and `usefirst<A, B>` (which calls `pair` and binds the result with `hold`) over `nn`/`ns`/`sn`/`ls`/`ln`/`sl`/`nsl`, each copy asserted exactly once, per-parameter C types checked, no `#error`, no implicit declaration, and gen1_min output **byte-identical** to gen2; two rejection cases (a parameter that does not use a type parameter, a return type naming an undeclared one) |
| `make test-gc` | gen2 mark & sweep from the language side: a 2000-iteration `concat` loop stays under 200 KB of live heap after `gc()`, `gc_runs()` counts a collection, `gc()` reclaims bytes, and the surviving string is intact (`len` + first byte) |
| `make test-seed-gc` | what memory management the two seeds actually have, measured under `ulimit -v` caps: seed-min has no collector (builder-backed strings plus a freeing assignment: 200k churn, 2000-step accumulation and a temp loop inside a 4 MiB cap; an 8388608-byte live set exits 1 with `sx: out of memory`; `gc()` refused at compile time), the full seed has a refcount representation whose counts never release in a loop (`SX_GC_DEBUG=1` reports 6000 objects alive after 2000 iterations, `gc()` is a no-op returning 0, `gc_live()` is an undefined function, a 4 MiB cap cannot start it) plus the operator-lexer fix that made it compile comparisons at all, and gen2 keeps a 200k churn and an 8 MiB live set correct inside 64 MiB, checks all three of its runtime allocations, and fails at 16 MiB with `sx: out of memory` instead of a segfault |
| `make test-generic-structs` | generic structs are refused **by name** on all three backends (`generic structs are not implemented`, gen2 also puts a `#error` in the generated C) instead of as a brace/undefined-name/field-count symptom; the concrete-name workaround (`NumBox`, `TextBox`, `PairBox` in one program) prints `7 seven 8 eight 2 8 9` identically on seed-min, gen2 and native; and a dotted field read inside a struct literal is pinned as seed-min-only (gen2 `#error`, native refuses) |
| `make test-sxpkg-online-optin` | the network is opt-in: `sync`, an `install` that has to fetch, and a remote `fetch` refuse without `SAYANOX_ONLINE=1` or `sxpkg --online <cmd>`, naming the opt-in and the offline commands and leaving no `.part` file; with the opt-in the same commands reach the transfer (a `.invalid` host, so they fail in the resolver and `sync` falls back to the offline seed); an all-local `install` and a `file://` fetch never ask |
| `make test-native-emit-split` (part of `native-test`) | the x86-64 backend is a region, not a seasoning: the 1302 lines between `EMIT-SEAM-BEGIN` and `EMIT-SEAM-END` contain no `e1(`/`e32(`/`e64(`, no `memcpy` into `code` and no direct read of the code cursor `cn` (labels come from `here()`), the seam primitives are all defined in the encoder region above `phase 1`, and an emitted program still runs. The refactor itself was checked byte for byte against the pre-seam binary on six fixtures |
| `make test-native-io` (part of `native-test`) | native `read_file`/`write_file`/`arg`/`arg_count` give the same results as seed-min and gen2 (argv[0] counted, truncating write returns 1, missing file reads as `""`, 160 KiB round trip) |
| `make test-native-mem` (part of `native-test`) | native memory with a real collector: a string doubled to 262144 bytes is served whole; 100000 `push`es keep every value; a 200000-iteration churn loop (~8 MB allocated, nothing retained) **finishes inside a 4 MiB `ulimit -v` cap** running 200+ collections; `gc_runs()` > 0, `gc()` reclaims bytes and `gc_live()` reports a positive live count; strings, list elements and struct fields survive 30000 allocating iterations; a program that genuinely retains 8 MiB still exits non-zero with stdout written before the failure kept and `out of memory` on stderr. See [`GC.md`](GC.md). |
| `make test-stage2-demos` | the three Stage-2 contract demos (`minimal_lexer`, `stage2_functions`, `stage2_variables`) compile byte-identically under seed-min and gen2; the string-only one also runs natively when `native_aot` is built (the native half is skipped, loudly, on the portable `true-selfhost` path, and executed in `make native-test`) |
| `make test-stage2` | gen2/gen1 Stage-2 parity plus seed/gen2 shared Stage-2 outputs and explicit seed limits (`test-seed-stage2`, `test-seed-limits`) |
| `make test-stdlib` | portable numeric helpers including interpolation on seed/gen2/native when built; string/list/file modules on gen2 and native; seed typed-module rejection |
| `make test-pkgs` | the offline package path: `sxpkg.sh init`+`seed` write `.sayanox/registry/{hello,math,strings}` with no network, `sxpkg add` records the lock, a program with `use \".sayanox/registry/math/main.sa\"` runs the same on seed-min, gen2 and native, and `sxpkg verify` passes on a clean project, reports the tampered `main.sa` as a `sum` MISMATCH, and passes again after the re-seed. **Plus the dependency path** on `registry/calc` (`deps=math@0.1.0`): `add` locks the closure and prints a line per package, the lock is compared byte for byte, `deps` prints the closure, a bare `install` reports `cannot write .sayanox/registry/<name>/`, `sh tools/sxpkg.sh install-local registry` installs both sum-checked, `verify` reports both, `use \".sayanox/registry/calc/main.sa\"` prints `36`/`25` identically on seed-min and gen2, and the `not in sx.lock` / `but sx.lock has` errors are asserted |
| `make test-gen2-gaps` | string `<`/`<=`/`>`/`>=`/`==`/`!=` by content on gen2 and seed-min, and native since 2026-10-10 (same output; string vs number is an error on seed-min); the gen2 fixes of 2026-10-08: `len(NAME)` in a range bound (list `sx_llen`, string `sx_len`); string `==`/`!=` between declared strings as strcmp (two equal runtime strings compare equal); `} else when`, `} else if` and `} otherwise when` chains including nested ones, with the same output as `elif`; seed-min and native match the conditional chain aliases; `%` inside builtin-call arguments is sx_mod, same as seed-min. |
| `make test-gen2-index-expr` | an index is a numeric expression in a value position, in a `when`/`while` condition, in a `for` bound and inside a typed function body: 39 hand-computed values identical on seed-min, gen2 and native; 9 unsupported index forms (`%`, a call other than `len()`, a comma, a quote, an empty index, unbalanced parentheses, a trailing operator, in each position) refused with a `min:` diagnostic and a `#error`; a negative index wraps on seed-min and gen2 and is asserted to stay refused by native. |
| `make test-gen2-expr-lowering` | the two gen2 expression gaps closed 2026-10-13: a string `+` chain in a `give`/condition joins through `sx_cat` (11 hand-computed values, `selfhost/gen2_str_cat_test.sa`), and `len(NAME)`/a nested `NAME[IDX]` inside `[ ]` lower to `sx_llen`/`sx_len` and `sx_lget`/`sx_idx` in a value, a chain operand, a condition, a `for` bound and a typed body (18 values, `selfhost/gen2_index_call_test.sa`) — both byte-identical on seed-min, gen2 and native, with the emitted C greps pinned; 6 unsupported forms (`%` in an index, a call other than `len()` in an index, a quote in an index, unbalanced brackets, a `+` with one string side, `%` with a string operand) refused with a `min:` diagnostic and a `#error`. |
| `make test-stdlib-modules` | the three stdlib modules added 2026-10-13 (`num_util`, `list_algo`, `str_text`): 99 hand-computed values identical on seed-min, gen2 and native, each module alone, and all seven modules in one program. |
| `make test-doc-claims` | no document advertises an entry point that is not in the repository: 24 legacy docs carry the "entry points do not exist" banner, `stage2_template.c` is still a placeholder, `restore_stage2.sh` still exits 1, and there is still no `stage2:` target. |
| `make test-registry-sums` | every `pkg.meta` `sum=` in the repository equals `sxpkg sum` of its `main.sa` (offline integrity; see [`REGISTRY.md`](REGISTRY.md)) |
| `make test-for-str` | the Stage-2 slice on gen2: `for c in <string>` byte walk, vowel count with `string_eq`, `break`/`continue`, empty string, nested loops, a rebound counter, `\"é\"` as two bytes, the diagnostics for a number, a list and a counter clash; seed-min matches named-source and literal cases; native runs string iteration; a `make NAME<T>` whose second parameter is not a type parameter is refused with the generic diagnostic. |
| `make native-test` | native subset, one slot per name, undefined names, list ops + push/grow + bounds, structs, nested structs (2 and 3 levels, typed copy incl. doubly nested, seed-min/gen2 output parity), `use` splice (depth 2, input-dir resolution, missing-file and unquoted-path errors), functions (recursion `fac`/`fib`, 6 params, forward refs, mutual recursion, zero-arg, global assignment, builtin and string args), postfix right of `* / %` + left-assoc, string `s[i]`/`sx_index`, `else`/`otherwise` false branch, unsupported constructs rejected (incl. give-outside, make-in-block, wrong arg count/type, non-numeric give) |

## Roadmap: done vs still missing, per backend (synced 2026-10-13)

This table replaces the 2026-10-08 roadmap. Every "done" cell names the gate
that checks it; a "missing" cell says why it is missing. "n/a" means the thing
does not exist on that backend by design (not a gap that is being hidden).

The three backends are `seed-min` (the C seed, `selfhost/seed/sxc_seed_min`),
`gen2` (the compiler built by `gen1_min`, which is what `true-selfhost`
ships) and `native` (`selfhost/native_aot`, x86-64 Linux only).

| Area | seed-min | gen2 | native | Gate(s) | Still missing |
|---|---|---|---|---|---|
| Pure-min bootstrap | root compiler | self-hosted C emitter | x86-64 Linux ELF | `doctor`, `true-selfhost`, `gen3`, `native-test` | no second native target; no full-language self-host claim |
| Numeric stdlib (`tiny.sa`, 40 definitions) | yes | yes | yes | `test-stdlib`, `test-stdlib-growth`, `test-stdlib-interpolation` | small numeric library, not JSON/HTTP/crypto; new helpers: lerp, saturate, smoothstep01, distance_sq |
| String/list/file utility modules | yes | yes | yes (already implemented) | `test-stdlib` | limited helpers, not a full portable I/O abstraction |
| Boolean literals, and/or/not | yes, values and conditions | yes | yes (pre-existing) | `test-seed-stage2`, `test-logic-value`, `test-native-cond`, `test-native-logicarg` | seed numeric/string/list bare assignment now supported (`test-seed-assignment`); gen2 has expression-context limits (e.g. chr logic arguments) |
| elif, conditional aliases, break/continue | elif, else-if/else-when/otherwise-when; breaks/continues in while and supported for | yes | yes | `test-stage2`, `test-full-lang`, `test-native-lang` | seed unsupported iteration forms remain explicit errors |
| String/list for | variables, literals, checked calls and dotted field chains, inside fully typed make AND inside untyped make; literals/calls captured once per entry | variables, literals, calls | yes | `test-for-str`, `test-seed-for-literals`, `test-seed-for-calls`, `test-seed-for-untyped`, `test-seed-for-fields`, `test-native-lang` | a `list`-typed struct field as a for source (`for v in p.xs`) and a parenthesised source (`for c in (s)`) are still hard errors in seed-min and gen2; native function-local for is frame-local and recursion/GC tested; `_sx_iter_` is reserved in seed |
| Numeric range for | numeric literals/variables/arithmetic, indexing and len; also inside fully typed make | yes | yes; upper bound re-evaluated per check | `test-seed-for-range`, `test-full-lang`, `test-native-lang` | all three re-read upper bound each condition. Seed accepts direct field access in a bound (`for i in 0..p.n`), so the older "hold field values in numeric variables first" note is stale; a user call in a range BOUND (`for i in 0..f()`) compiles on gen2 and native but seed-min still refuses it (`seed-min for range bounds support len(...) but not other calls yet`) — verified 2026-10-13 |
| Function generics | num/str/list specialization; one or multiple type parameters | num/str/list monomorphisation | num/str/list monomorphisation (pre-existing) | `test-generics`, `test-seed-limits`, `test-native-generics`, `test-native-strgen`, `test-native-listgen` | generic structs and some backend-specific body/lowering gaps |
| Typed functions | num/str/list parameters and returns, isolated locals, control flow, terminal give | broader typed functions, some lowering gaps | typed functions; kind-preserving parameter reassignment | `test-seed-typed-functions`, `test-typed-sig` | seed global capture and full return-path inference remain absent |
| Function-local hold | yes | yes | frame-local, recursion tested | `test-native-locals`, `native-test` | no new ABI or second architecture |
| Explicit hold types | num/str/list outside make and inside fully typed make; initializers, assignments and reannotations checked | num/str/list syntax already accepted | num/str/list, also function-local and bound generic T | `test-seed-hold-types`, `test-full-lang`, `test-native-generic-local` | seed untyped-function annotations and generic structs; see [type design](TYPES_ROADMAP.md) |
| Struct types | literal-typed | literal-typed | literal-typed | `test-struct2`, `test-nest`, `native-test`, `test-generic-structs` | generic structs still deferred with layout/GC rationale in [TYPES_ROADMAP.md](TYPES_ROADMAP.md); since 2026-10-13 the *refusal* is uniform and names the missing feature on all three backends, and a dotted field read inside a struct literal is pinned as seed-min-only |
| GC | no collector (builder-backed strings plus a freeing assignment wrapper) | mark/sweep, all three runtime allocations checked | mark/sweep | `test-gc`, `test-native-mem`, `test-seed-gc` | measured 2026-10-13: seed-min is documented no-GC and fails as `sx: out of memory`; the full seed's refcount table never releases in a loop (`SX_GC_DEBUG=1` reports 6000 objects alive after 2000 iterations) and `gc()` there is a no-op; gen2's first collection fires at 8 MiB of managed heap, so it needs more address space than native; conservative native stack scanning |
| Packages, offline | tool built by gen2 | registry/lock/deps/install-local/verify | not a native-tool claim | `test-pkgs`, `test-sxpkg-polish`, new `test-pkg-errors` | search no longer implicitly syncs; shell still supplies filesystem/process operations; execution failures now propagate |
| Packages, online | not bootstrap | explicit sync/install/fetch commands, **opt-in** since 2026-10-13 | n/a | `test-sxpkg-online-local`, `test-sxpkg-online-optin` (both in the aggregates, both socket-free) | no cryptographic integrity, no signatures, no remote publish; `SAYANOX_REGISTRY` says where, `SAYANOX_ONLINE=1`/`--online` says whether |
| LSP | tool built by gen2 | existing .sa JSON-RPC server | n/a | `test-lsp`, `test-lsp-robust`, `test-lsp-unicode` | **four documents** open at once since 2026-10-13 (a fifth evicts the oldest), each request answered from its own URI's buffer and an unopened URI answered empty; still no workspace index or cross-file analysis; UTF-16/Unicode and empty changes tested by `test-lsp-unicode` |
| Platform | host C | host C | x86-64 Linux only | four bootstrap gates | other native platforms unsupported, not emulated |

### Changes and verification in this pass

* Added four portable numeric helpers and hand-computed cross-backend tests.
* Added the bounded seed Stage-2 subset above, including precedence,
  short-circuit guards that would otherwise divide by zero, nested loops,
  source rebinding, empty strings and UTF-8 byte iteration. Extended existing
  stage2/for-str gates; replaced obsolete continue/elif rejection tests with
  exact-output tests. Unsupported iteration and generic forms fail explicitly.
* Strengthened the shared `assert-out` helper: correct stdout with a nonzero
  process exit is now a test failure. The intentional native OOM test instead
  explicitly checks nonzero status, retained stdout and the OOM diagnostic.
* Packages: search without a local index is an offline error, not an implicit
  download; checked wrapper no longer swallows execution/project failures.
* Re-tested existing native boolean values, numeric/string/list generics,
  local holds, offline packages and LSP probes. Did not reimplement or claim
  these as new features. Corrected prior contradictory roadmap rows.
* Generic structs have a design/deferral document. The first pass did not add
  hold annotations or LSP protocol changes; the continuation below does. Seed
  generics, a full inference rewrite and native ABI changes remain unfinished.
* No Linguist PR, no extension remapping, and no network bootstrap step.

`selfhost/STAGE2.md` describes a legacy separate stage2 binary. The maintained
path is seed-min → gen1_min → gen2 → gen3/gen4, with byte-identical gen3/gen4
checked by `make gen3`. `true-selfhost-full` remains unimplemented.

### Continuation: remaining-work progress

* Seed-min bare assignment for existing numeric/string/list variables now
  shares the hold emission path, with explicit type mismatch errors. Added
  conditional aliases (`else if`, `else when`, `otherwise when/if`) to both
  scanner and emitter; old rejection tests now compare real output with gen2.
* Added checked seed `hold name: num/str/list` outside functions. Function-local
  annotations and parameters shadowing annotated globals fail clearly rather
  than silently reusing incorrect storage. See `test-seed-hold-types`.
* Fixed seed string self-assignment for underscore/runtime-prefix variable
  names and collision with the old generated `_sx_v` temporary. Prefixes no
  longer imply owned runtime-call results. A separate seed-only regression
  fixture also ran under AddressSanitizer (leak checking disabled). Gen2 does
  not currently compile the leading-underscore fixture; no parity is claimed
  for those names.
* LSP now handles UTF-16 positions and BMP/surrogate-pair JSON escapes. Added
  real protocol tests with Latin/Bengali/emoji, empty document changes, empty
  change arrays, unrelated-URI changes, and close-state cleanup.
* Each area passed doctor/true-selfhost/gen3/native-test. The final logs were
  regenerated after the edge-case fixes. No seed generics, broader iteration,
  generic structs, multi-document LSP or second native target is claimed.

### Next increment: literal iteration (2026-10-12)

Seed-min now accepts `for ch in "abc"` and `for value in [1, 2, 3]`
outside `make`. Each literal source is evaluated once per loop entry into a
reserved hidden temporary, including numeric expressions/calls within a list.
Named sources retain their existing re-read-each-iteration semantics.

`test-seed-for-literals` is included by both `test-stage2` and `test-for-str`.
It checks hand-computed output on seed/gen2, plus native parity when built:
side effects occur once per entry, body mutations do not re-evaluate the list,
empty loops execute no body, nesting works, break/continue progress correctly,
and UTF-8 strings iterate by byte. Incompatible binders, nonnumeric list
members, reserved-name collisions and unsupported source expressions fail.
At the end of that increment, range sources, call-result sources, function-local
for, and seed generics remained unfinished. Numeric ranges are added below. This change does not introduce a
collector into the seed runtime.

### Next increment: numeric range iteration (2026-10-12)

Seed-min now accepts `for i in 0..N`, including negative/fractional bounds,
arithmetic, parentheses and `len` of lists/strings. The start is assigned on
entry, the upper expression is re-read on every condition test, the comparison
is strict `<`, and the counter advances by 1. `continue` reaches that step;
`break` leaves without stepping. Reassigning the counter affects progression.
An empty/reversed range performs no body. New counters are numeric; an existing
string/list counter or a language-keyword binder is rejected.

`test-seed-for-range`, part of `test-stage2`, checks exact seed/gen2 output and
rejection of malformed bounds, wrong types, invalid len arity/operand,
undefined names, bad indexing, unsupported calls/fields and invalid numeric
literals. The `..` lexer exception applies only inside range headers: `show
1..2`, `show 2.` and `show 1.2.3` remain errors. Old range-rejection tests in
`test-full-lang` and `test-native-lang` are now positive seed output checks.

**Historical divergence (fixed by the native range increment below):** native evaluated its upper bound once, while
seed/gen2 re-evaluate it. Changing `limit` or replacing the list used by
`len(xs)` inside the body therefore yields different loop counts. The new
native regression leg asserts a separate, hand-checked snapshot expectation,
not false cross-backend parity. Native code was not modified. Predeclare a
native counter if its post-loop value is needed. This semantic alignment is
still missing work, not silently fixed by the seed implementation.

The seed range subset deliberately refuses function calls other than `len`
(and its existing `sx_len` alias), direct field access in bounds, and all for
loops inside functions. At the end of the range increment, call-result iteration was still unfinished.
The producer/call increment below adds a subset; seed generics and
function-local iteration remain unfinished.

### Earlier increment: call-result iteration and typed producers (2026-10-12)

Historical boundary: the following describes that increment alone. The fully
typed-function increment below supersedes its parameter/body restrictions.

Seed-min now accepts plain string/list-producing calls as `for` sources,
including checked builtins and zero-argument user producers with explicit
`-> str` / `-> list` returns. The call runs once per loop entry; its returned
reference is kept in a hidden temporary. Rebinding an input string during
the loop does not re-run the call. List references are not deep copies, so
mutations to the same list remain visible. Numeric call results are refused
as collection sources. Numeric range-bound restrictions are unchanged.

All parser passes share a function-header reader and a signature registry.
Generated C has prototypes, and call result kinds drive both expressions and
global hold collection. New annotated producers have isolated local symbol
tables; they cannot accidentally reference main's C locals. Argument
count/kind checks apply in call-source and producer expressions. Return kinds
are checked; a producer must end in an unconditional give. Supported bodies
are straight-line hold/show/give/push/assignment statements. Parameters,
control flow, global capture, structs and local hold annotations are not
added to this producer subset. Existing unannotated numeric functions remain
available. Generic monomorphisation is not implemented by this registry.

`test-seed-for-calls` is included by `test-stage2` and `test-for-str`. The shared
fixture checks one evaluation per entry, returned strings/lists, producer
locals versus same-named globals, nested/empty loops, break/continue, builtin
sources (including read_file) and ordinary holds of producer results, with
hand-computed output on seed/gen2 and native parity when built. Negative
cases cover mismatched gives/arguments, missing terminal give, unsupported
bodies/parameters, unknown functions/variables and duplicate definitions.
The seed's 16-argument and 64 KiB call-lowering limits now fail explicitly.

A separate seed-only fixture checks typed forward calls and literal-list
returns. At that step gen2 lacked typed forward prototypes (now fixed below)
and had limits on direct list-literal returns/nested push literals (bounded
support is added in the later list-expression increment); the shared
fixture uses declaration order and named list locals. No broader gen2/native
parity or general typed-parameter support is claimed. Seed allocations remain
uncollected; this does not add a GC or a leak-free runtime.


### Fully typed seed functions (2026-10-12)

Seed-min now accepts all-or-nothing num/str/list parameter annotations with
explicit num/str/list returns. Calls check argument counts and kinds, even
in main and nested argument expressions; prototypes carry the same kinds.
Fully typed functions have isolated parameters/locals, stable kinds, local
hold annotations, conditional/loop control flow, early returns and supported
for forms. New nested-block locals expire at block end. Existing outer holds
reassign rather than shadow. A terminal top-level unconditional give remains
mandatory. String parameters are copied before local mutation; list parameters
retain shared-reference semantics. This is not a GC implementation.

`test-seed-typed-functions` covers alias-safe string parameter assignment,
list mutation, recursive calls, while/when, annotated locals, recursive for,
nested list/string walks, break/continue, checked call sources, scope errors,
wrong call arguments and signatures. Extended fixtures compare seed/gen2;
seed-only cases cover sibling-block names, typed forward calls and boolean
literal call arguments. Those cases now also pass on gen2, as recorded below. Native
now passes the typed-parameter fixture via test-native-param-reassign, but
now supports function-local for, tested with a shared unannotated-local
fixture. The original annotated-local fixture now also runs on native.

`test-typed-sig` now runs its numeric recursion fixture on all three backends;
`test-stage2` compares its mixed fixture on seed/gen2/gen1_min. `test-stdlib`
now runs str/list/file utility modules on seed and compares all output with
gen2, retaining the existing native expected-output test.

At that increment, still missing: seed generic specialization, generic structs/concrete type
identity, global captures in typed seed functions, general return-path
analysis, untyped-function for, arbitrary iterable expressions, native list-alias behavior across capacity
growth and the gen2 lowering gaps above. See SYNTAX.md and
TYPES_ROADMAP.md for the exact supported boundary.

Validation after the final nested-call argument guard: `make doctor`,
`make true-selfhost`, `make gen3` and `make native-test` all exited 0; gen3 and
gen4 were byte-identical. Logs: `docs/logs/make-doctor.log`,
`make-true-selfhost-min.log`, `make-gen3.log`, `make-native-test.log`, and
`seed-typed-functions.log` (paths relative to docs/logs for the latter four).


### Native parameter reassignment and live range bounds (2026-10-12)

Two separately gated increments:

* Native assignments to parameters now enforce each parameter's declared
  num/str/list kind and store into its call-frame slot. Lookup matches reads:
  a parameter takes precedence over a same-named global. Statement-boundary
  recognition now permits a following parameter assignment (actual binding
  validation remains in the statement emitter). No eager free is introduced;
  native strings returned by concat are fresh, and the collector scans frames.
* Native numeric range upper expressions now execute at each condition check,
  rather than before the loop. The start is still evaluated only on entry.
  Break does not recheck; continue advances the counter then rechecks.

`test-native-param-reassign` covers the previous typed-parameter fixture,
string recursion/caller preservation, list rebinding/mutation, wrong-kind
errors, same-named globals and explicit GC across recursive frames. The new
portable fixture matches seed/gen2/native. GC/name-collision cases are tested
separately on native. List capacity-growth alias parity is NOT established:
the native runtime may replace a list object on growth, leaving other aliases
on its older storage. This remains runtime work.

`test-seed-for-range` now uses ONE expected output for all three backends,
including shrinking bounds and len of a replaced list. The native-only
`test-native-range-live` also checks upper-call side effects, empty ranges,
break and continue; seed/gen2 reject user function calls in range bounds.

After EACH increment all four gates exited 0, with byte-identical gen3/gen4.
Canonical docs/logs gate logs now contain the final range increment. Focused
logs: native-param-reassign.log and native-range-live.log. Seed generic
specialization, generic structs, native function-local for and documented
gen2 lowering gaps remain unfinished; these changes do not claim them.


### Native function-local for, list aliases, seed generics (2026-10-12)

Three further implementation areas were completed and separately gated:

1. **Native function-local for:** range/list/string loop binders and hidden
   state now occupy the current call frame, not global slots. Parameter
   binders reuse their parameter slot with kind checks; new locals do not
   mutate same-named globals. Hidden names cannot be spelled by source code.
   Recursive loops, nested loops, early return, break/continue, explicit GC,
   binder mismatches and hidden-name collisions are tested. There is a clear
   64-level loop-nesting limit. The first shared fixture uses inferred locals; a subsequent native
   annotation increment below covers the original typed-local fixture too.
2. **Native list growth aliases:** payload +8 now holds a successor link.
   Push resolves the latest object and links growth back to the old object;
   len/index/show resolve the same chain. The collector traces the link,
   not numeric elements. No same-named global is rewritten when pushing a
   parameter. Tests cover 100-element growth through a parameter, different
   generations of aliases, ordinary rebinding, explicit collection and
   reclaimed-block reuse. Old aliases can retain earlier growth buffers;
   this is not a compacting collector or a no-overhead identity scheme.
3. **Seed generic functions:** a demand-driven worklist generates and checks
   concrete num/str/list bodies, with independent type variables, recursive
   calls, mutual recursion, local type annotations, deduplicated variants,
   prototypes and deterministic output. Function/type/source limits fail
   explicitly. No generic struct syntax or layout is implied. Shared tests
   cover basic/multi-type calls and numeric recursion on all three backends;
   extended nested/string-only recursive cases are seed-only because of
   an observed gen2 limitation. Native now passes the extended fixture after
   demand-driven generic emission. See GENERICS.md for the exact contract.

Focused targets: test-native-for-functions, test-native-list-alias,
test-seed-generics (also the existing test-generics multi-parameter fixture).
Each area passed doctor, true-selfhost, gen3 and native-test before moving
on. Final canonical logs include the combined changes and final hardening.
Seed compiler ASan/UBSan checks on the extended/scope generic fixtures also
passed with leak detection disabled (not a runtime leak-free claim).

**At that increment, still incomplete:** generic structs/concrete type
identities and cross-backend layout/GC checking; gen2 forward/scope/boolean/
list-expression and nested-generic lowering gaps (see the later fixes below); broader iterable-expression/seed untyped-function
support and whole-function return analysis. These are not reported as PASS.


### Native local annotations and demand-driven generic bodies (2026-10-12)

A fourth separately gated area adds optional num/str/list hold annotations
to native collection, inference and emission. Concrete generic bodies can
use `hold x: T`; wrong types and unknown annotations fail explicitly. Native
now compiles the original annotated typed-loop fixture and the existing
multi-parameter generic/local-annotation fixture.

Numeric generic bases join the same demand worklist as string/list variants;
unused templates no longer force a numeric body. This fixes the string-only
recursive template in seed_generics_extended_test.sa on native, while that
fixture still exposes a gen2 nested-specialization failure. A separate shared
fixture checks annotated locals, list aliases, string-only templates and an
unused body across all three backends. No gen2 source was changed here.

After this final area all four gates again exited 0, including byte-identical
gen3/gen4. Canonical logs in docs/logs now correspond to these final changes.
Generic structs and the documented gen2/scope/expression gaps remain open;
this is substantial progress, not an all-language-complete claim.


### Gen2 forward calls, function scope, booleans and nested generics (2026-10-12)

Four separately tested and gated compiler_min.sa increments:

* **Typed forward prototypes:** ordinary num/str/list functions now contribute
  C prototypes before bodies; generic prototypes are reused. Zero-argument
  definitions use void. String/list forward returns and mutual recursion
  pass strict C prototype/implicit-declaration checks and seed/native parity.
* **Function declaration scope:** function name tables start empty before
  parameters are registered. Source blocks preserve outer declarations but
  expire newly introduced locals; sibling branches can use the same name
  with different kinds. Nested while/for and elif wrapper bookkeeping are
  tested. Legacy top-level flat declaration tracking remains unchanged.
* **Boolean call arguments:** whole true/false tokens in expression positions
  lower to doubles, preserving strings, longer identifiers and boolean-named
  struct fields. A shared fixture passes on seed/gen2/native; comparison
  arguments are separately gen2-tested (native rejects that case).
* **Nested generic queue:** consecutive request separators no longer turn a
  kind into a bogus function name. Template lookup only examines record
  headers, not matching parameter/body fields. The previously crashing
  extended generic fixture and a name-collision fixture now pass. Extended
  emitted C is identical between gen1_min and gen2.

Targets: test-gen2-forward, test-gen2-function-scope,
test-gen2-boolean-args, test-gen2-generic-queue. The original
seed_typed_scope_test.sa was also manually checked on gen2: output
9 / 11 / forward! / 1. The scope fixture is seed/gen2, not a claim about
native sibling-kind scope semantics or complete undefined-name analysis.

After each area doctor, true-selfhost, gen3 and native-test exited 0;
gen3/gen4 remained byte-identical. The offline compiler bundle was regenerated
with make pack-compiler after each source increment and its decoded bytes
compared to the source. Final SHA-256:
a8c0bbf59df4316fdbdf803bc7121eee1d8a6a7d92bfdb9e92c67a075cae3ccc
(96 gzip/base64 parts of at most 1100 characters).

At that increment, still open: generic structs/concrete type identity and
layout/GC work; direct list-literal returns/general list expressions on gen2; complete
undefined-name/return-path analysis and broader iterable/legacy-function
support. Further generic inference edge cases are not implied fixed by a
queue repair. No all-language-complete claim is made.


### Gen2 list returns, literal call arguments and GC anchor (2026-10-12)

Three further separately gated areas:

* Direct complete list-literal returns in -> list functions now lower through
  the existing checked hold/list parser at the return's original location.
  Empty/arithmetic-element lists, observed element calls, early returns,
  forward/generic functions and collision-free temporary names are tested.
  Seed/gen2/native output matches; gen1_min/gen2 generated C is identical.
* Empty/signed-decimal numeric list literals now work inline in call arguments,
  including push, len, user/generic calls and nested pushes. Allocations remain
  inline (a loop-condition regression detects accidental hoisting). Casts to
  double preserve the variadic list ABI. List-valued literal/call operands
  select list helpers. Expression elements still require a named hold;
  unsupported/malformed inline forms produce #error diagnostics. Direct
  list sx_index is a separate gen2 case, not native parity.
* An additional -O0 check exposed an existing GC anchor placement problem:
  the optimizer-dependent layout could put the main anchor below live locals.
  Generated programs now execute under a caller-frame anchor via a volatile
  indirect call and post-call store. Both -O0 and -O2 compiler binaries emit
  identical C for the new fixtures; generated programs preserve string/list
  and function roots across 2,000 explicit collections. Name collisions are
  tested. This is a tested-host fix, not a universal conservative-GC proof.

Targets: test-gen2-list-return, test-gen2-list-args, test-gen2-gc-roots.
The failed -O0 probe was fixed before final validation, not waived. After each
area all four gates exited 0; the final combined gen3/gen4 are byte-identical.
The offline compiler bundle was regenerated and round-trip checked. That increment
source SHA-256: ab08bb4c7d181189d16f97a1817f91a11f68b8a506be83e43c137150ce9e8e14
(99 parts, at most 1100 base64 characters each).

Still missing: generic structs and concrete type/layout/GC identities;
fully general inline list expressions (use named holds for numeric expression
elements), complete undefined-name/return-path analysis, and the other
backend-specific expression/scope limits documented above. None are marked
complete by these bounded additions.


### Gen2 inline list constant arithmetic (2026-10-12)

Extended the inline literal parser from signed decimal atoms to constant
arithmetic: unary signs, + - * / and balanced parentheses. Decimal tokens
are normalized to doubles before C emission, preserving fractional division,
precedence and left associativity. Parentheses inside a list no longer
misroute the enclosing call to the numeric-only grouping-expression path;
return/condition rewrites leave list division to the list parser. Call-text
collection retains whitespace inside brackets, so `[1 2]` is diagnosed
instead of silently becoming `[12]`.

`test-gen2-list-arithmetic` verifies generic list results, nested push/len,
return and when/while call paths, fresh loop-condition allocations, quoted
text, fractional division and leading-zero decimal constants. Seed/gen2/native
outputs match; gen1/gen2 C is identical; generated -O0/-O2 programs both pass.
The expanded negative suite rejects malformed groups/numbers, adjacent
numbers, names/calls, modulo/comparisons, nested lists and list postfix forms.
Both targets are part of the standard gates.

The offline bundle was regenerated and round-trip checked (99 parts).
Current compiler SHA-256:
f33bf80644ae6ccafd24fd8cbf1023e67170ffcfc85b2dbcaa48e3002321537c
All four gates exited 0, with gen3/gen4 byte-identical. Actual focused logs
and gate tails: docs/logs/gen2-list-arithmetic.log and
docs/logs/gen2-list-arithmetic-gates.log; canonical gate logs are refreshed.

Still open: inline elements containing names/calls (use a named hold),
modulo/comparisons in inline lists, general list postfix/compound expressions,
generic structs, and full undefined-name/return-path analysis. This is a
bounded extension, not completion of the expression/type-system roadmap.


### Structural return paths across three frontends (2026-10-12)

Implemented a conservative structural return proof in the seed, gen2 and
native frontends. Explicitly typed functions and generated generic instances
must not fall through. Exhaustive/nested branch chains and returning suffixes
are accepted; seed's old terminal-top-level-give restriction is removed.
Loops may execute zero times for proof purposes; no constant-condition or
termination analysis is claimed. The scanner ignores strings/comments and
balanced expression delimiters, and refuses to prove nesting beyond 128.
Ordinary expression/type validation remains separate. Untyped behavior is
unchanged.

`test-return-paths` is wired into test-typed-sig and native-test. It checks
num/str/list and generic successes against all three backends, byte-identical
gen1/gen2 C, and missing arms, nested fallthrough, loop-only returns,
unreachable loop returns, and fake give tokens in comments/strings. C output
is also built with -Werror=return-type. The fixture exposed and now regresses
two gen2 bugs: a nested real else could prematurely close an enclosing elif
wrapper, and give text treated quoted braces/comment markers as syntax.

All four gates exited 0; gen3/gen4 remain byte-identical. Packing crossed 100
parts and exposed lexicographic misordering of two-digit chunk filenames.
The packer now writes four-digit filenames; restore also accepts the legacy
first-chunk filename. The 101-part bundle round-trips, and a missing-source
restore to a separate test path was compared byte-for-byte with the source.
Current compiler SHA-256:
d740da4a6745b5f30aa3b5de278bf3fa33b9b1786e7b556c17ad2d18ddfbdddd
Logs: docs/logs/return-paths.log, return-path-gates.log, return-path-restore.log,
and the refreshed canonical gate/pack logs.

Still unfinished: generic structs/concrete type identities and layouts;
inline-list variables/calls/modulo/comparisons and general list expressions;
complete undefined-name checking and the other backend limitations recorded
above. The structural return-path portion is implemented, not the whole
compiler roadmap.


### Gen2 reference resolution (2026-10-12)

Implemented pre-lowering value/call reference checks using the current binding
and signature tables, across hold/show, assignments/indexed writes, push,
conditions, for headers and give. Nested call arguments and list/index
expressions are included. Unknown values/callees now produce explicit #error
diagnostics; they are not left as unexplained identifiers in generated C.
Function scope expiry prevents parameters/branch locals leaking to other
scopes. Forward signatures, generic instances, field labels/selectors,
builtin-like binding names, and quoted/commented text retain their behavior.

The first true-selfhost run exposed a missing string-iterator binding in the
lookup: those binders can exist in sdecls without decls. Lookup now covers all
three value tables; a generic string-iteration regression was added. After
that fix, the focused target and all four gates exited 0. gen1/gen2 fixture C
and gen3/gen4 compiler C are byte-identical. Positive output agrees across
seed/gen2/native; 31 negative programs cover missing references/callees.

`test-name-resolution` is wired into test-typed-sig and native-test. Logs:
docs/logs/name-resolution.log and name-resolution-gates.log, with the canonical
gate and pack logs refreshed. Offline bundle round-trip passed (103 parts).
Current compiler SHA-256:
1be1bdd3f4b38fe6625472df16f25c993f683431cf7178ee6653fc5c7df888b7

Boundary: name lookup follows the existing binding contract; the legacy
main-level flat policy is unchanged, and this does not prove definite
assignment or perform complete expression type inference. Generic structs,
inline list variables/calls/modulo/comparisons and general list expressions
are still unfinished. These are not marked complete by the name checks.


### Typed inline numeric-list expressions (2026-10-12)

Implemented pre-emission typed lowering for inline list literals in supported
expression statement paths. Elements now accept numeric names, arithmetic,
modulo/comparisons, indexing, numeric-returning ordinary/generic calls, and
nested list consumers. Nested calls check parameter counts/kinds and returns;
wrong element/operator/index kinds are rejected. Concrete generic parameter
metadata is registered at request time as well as definition time.

Generated automatic double temporaries plus comma expressions preserve the
variadic ABI and left-to-right, single evaluation of inline list elements.
Their declarations are outside the statement, but assignments and allocation
stay inside each expression (including every loop-condition check). A private
prefix avoids source-name collisions. This guarantee is for the new inline
path; existing hold/direct-return list lowering is not rewritten. Seed's
variadic evaluation order is not claimed to match. Native list kind inference
and element counting now use its comparison-aware parser.

Tests: test-inline-expressions and test-inline-runtime, wired into the gates.
The common expression fixture matches seed/gen2/native. Separate sequence
fixtures match gen2 -O0/-O2 and native, covering side effects, mutable-list
observations, fresh conditions and helper-name collisions. Negative cases
cover type/arity errors, malformed expressions and unsupported postfix forms.
Additional -O0/-O2 compiler binaries emit identical C for the expression fixture.

An extra minimal test after the initial green gates found that inline-only
string expressions failed to request string runtime helpers. This was fixed,
a permanent regression was added, and all four gates were rerun successfully.
Final doctor/true-selfhost/gen3/native-test exit 0; gen3/gen4 are byte-identical.
The offline bundle round-trip passes (107 parts). Current compiler SHA-256:
71402d5e701251336eb4658fcda801de9917b26bd7fe5f466cc4dc596b0b8d50
Logs: docs/logs/inline-expressions.log, inline-expression-gates.log,
inline-expression-extra.log, plus refreshed canonical gate/pack logs.

Remaining: generic structs/concrete layouts and type identities; arbitrary
list postfix/compound expressions and inline struct-field expressions (use
named numeric holds); seed sequencing parity; full type/definite-assignment
analysis and previously documented backend limits. These are not marked
complete by this increment.


### Seed sequencing and checked field/list postfix calls (2026-10-13)

Two implementation areas were independently four-gated:

1. Seed numeric list constructors now use a source-collision-free linked
   builder stack and comma expressions. Element evaluation is left-to-right
   and once only, including nested/recursive constructors. Shared sequencing
   and builder-collision fixtures pass seed O0/O2, gen2 and native.
2. Gen2 inline numeric-list elements now resolve named/nested struct fields.
   Known calls containing list/index syntax are parsed as whole typed
   expressions, accepting grouped literal indexing and indexed list-returning
   calls while checking outer argument kinds. Generic argument inference
   refines first-token guesses with resolved expression kinds; nested list
   commas no longer split multi-parameter arguments. Seed permits checked
   named-struct/field-chain access only after validating the field metadata.

`test-list-postfix` checks seed/gen2/native parity and seed/gen2 rejection of
unknown fields, nonstruct selectors, nonnumeric elements, invalid index kinds
and list-parameter mismatches. Existing inline expression regressions remain
green. Both new targets are wired into typed-signature/native-test gates.

Actual results after EACH area: doctor, true-selfhost, gen3 and native-test
all exited 0; gen3/gen4 were byte-identical. Full logs:
`docs/logs/seed-sequence-gates.log`, `docs/logs/list-postfix-gates.log`.
Focused logs: `docs/logs/seed-list-sequence.log`, `docs/logs/list-postfix.log`.
Canonical gate logs are refreshed to the second area's run.

Offline bundle round-trip passes (109 parts). Current compiler SHA-256:
7ca320d53672c33c19396d607b18872ec818985f6af38c45047a9e66492ca061
See `docs/logs/gen2-offline-pack.log`.

**The full requested scope is not complete.** Generic structs/concrete layout
and type identities remain unimplemented. Arbitrary literal-headed postfix
and compound expressions outside the checked call paths remain open (for
example direct `hold n = [1][0]`). Gen2 legacy named-hold/direct-literal-return
list constructors still lack the new ordering guarantee. Struct-valued field
initialization retains the documented nested-literal restriction. Full type
inference/definite assignment and previously documented backend limits are
not claimed. The older increment sections above are historical snapshots.


### Seed `for` inside untyped `make`, call and field sources (2026-10-13)

The last unsupported seed `for` forms are now compiled rather than refused.
Nine changes to `selfhost/seed/sxc_seed_min.c` (`for_header`,
`field_chain_source`, the struct-metadata pass and the emitter) plus two gen2
fixes in `selfhost/compiler_min.sa`:

1. `for v in make_xs()` — a call as the iteration SOURCE, inside or outside a
   `make` body. The call is hoisted into the hidden per-loop temporary
   `_sx_iter_src_%u`, so it is evaluated once per loop entry, exactly like a
   literal source. The result must be `str` or `list`; anything else is a
   `seed_min:` error, and a call whose type is not yet known in an early pass
   resolves non-fatally instead of poisoning the pass.
2. `for v in p.items` and `for c in p.name` — dotted field chains as sources,
   walked by `field_chain_source()`, which stops at `..` so a numeric range
   bound that contains a field is still parsed as a range.
3. `for` inside an UNTYPED `make` body (no parameter or return annotations),
   where the body scope is isolated: hidden temporaries are per-loop, and the
   iteration variable does not leak.
4. A struct local declared inside a `make` body (`hold p = P { n: 2 }`) is
   accepted by seed-min, gen2 and native and prints the same value.
5. Field-source parsing resolves non-fatally in the early passes and is only
   enforced once `types_final` is set; routing it through `atom()`/`expr()`
   early was tried and rejected, because those helpers hard-fail on names the
   type pass has not registered yet.
6. `atom()`'s undefined-name check had to keep an exemption for a struct
   literal (`find_struct(id) >= 0 && S[P] == '{'`); without it, valid struct
   locals stopped compiling.
7. gen2 emitted `sx_len` without the `static double` storage class in one path,
   which broke `-Werror` builds of the generated C; fixed in
   `compiler_min.sa`.
8. An index mutated in the same statement that dereferences it
   (`si = -1; kind = SD[si].fty[ff] ? ...`) read `SD[-1]`, because the
   assignment is sequenced before the right-hand side. The index is now set in
   a separate statement. This is a language-level trap worth remembering: never
   mutate an index in the same statement that dereferences it.
9. `test-seed-limits` used to assert a refusal loop for a form that is now
   supported. That case was converted into an exact-output positive check, as
   is the convention whenever a documented limitation is removed.

Fixtures and expected stdout (three-way identical, hand-computed):

* `selfhost/seed_for_untyped_test.sa` →
  `6,a,b,c,x,y,7,8,9,0,1,2,3,12,a,b,c,d,0,2,4,6,0,untyped-for-done`
  (`SFU_WANT`, `make test-seed-for-untyped`)
* `selfhost/seed_for_fields_test.sa` →
  `a,b,x,y,7,p,q,z,0,a,c,2,2,m,n,2,2,3,fields-done`
  (`SFF_WANT`, `make test-seed-for-fields`)

Both targets also assert that gen2 emits `static double sx_len`, that a struct
local inside a `make` body compiles to `7` on all three backends, and that 10
(seed-for-untyped) plus 6 (seed-for-fields) malformed programs exit non-zero
with `seed_min:` in stderr — including `for v in p.xs` where `xs` is a
`list`-typed field, and `for c in (s)`, which stay hard errors by design in
both compilers.

Not claimed: a global read inside an untyped `make` body is still refused by
seed-min and gen2 (native prints the value — recorded under "Measured
divergences"), and neither compiler gained parenthesised or list-typed-field
iteration sources.

### Stdlib growth: `num_util.sa`, `list_algo.sa`, `str_text.sa` (2026-10-13)

Three new modules, 52 helpers, in `make test-stdlib-modules` (wired into
`test-stdlib`, `test-stdlib-growth`, `test-stage2`, `test-for-str`,
`native-test` and the `true-selfhost-min` aggregate):

| Module | Prefix | Helpers | Notes |
|---|---|---|---|
| `stdlib/num_util.sa` | `nu_` | 17 | untyped and numeric, so the native-AOT subset runs it too, like `tiny.sa` |
| `stdlib/list_algo.sa` | `la_` | 17 | typed `list` parameters; every transform returns a NEW list |
| `stdlib/str_text.sa` | `t_` | 18 | typed `str` parameters; byte-oriented, ASCII-only |

`selfhost/stdlib_modules_test.sa` prints 99 hand-computed values, and seed-min,
gen2 and native must print byte-identical stdout — including two deliberately
empty lines (`t_slice("hello", 9, 2)` and `t_trim("   ")`) and two lines with
trailing/leading spaces (`t_pad_right`, `t_pad_left`). The target additionally
compiles each module alone, and compiles all seven modules together in one
program on all three backends, which is what proves the new prefixes do not
collide with the existing `s_`, `l_`, `f_` and `tiny.sa` names.

`nu_trunc` is built on the one double-to-integer conversion the pure-min
dialect offers — `x % 1000000000000000`, because `sx_mod` casts both operands
to `long` — and every other rounding helper derives from it. Verified identical
on seed-min, gen2 and native: `2.75 → 2`, `-2.75 → -2`, `-7 % 3 → -1`.
`nu_mod_pos` is Euclidean modulo (sign of the divisor), `nu_int_div` floor
division, `nu_pi` prints `3.14159` because `show` uses `%g`.

Two gen2 limitations shaped the library and are recorded under "Measured
divergences" rather than hidden:

* gen2 index expressions had to be a literal or a plain name when this module
  was written, so `la_sorted` carried the previous element in a variable
  instead of writing `xs[i - 1]`. Superseded later the same day by the
  index-expression increment below: `la_sorted` now reads `xs[i] < xs[i - 1]`
  and is the live stdlib exercise for it. The second limitation still stands.
* a bare `give "a" + b` inside a function body does not compile on gen2, so
  every string helper accumulates into a `hold` and returns that.

Honest boundary: this is growth of a small portable library. There is no JSON,
no HTTP client, no date/time, no unicode (strings are C `char *`, one byte per
"character", so a multi-byte UTF-8 sequence is split), and no transcendental
math beyond `nu_pi` and the degree/radian conversions. `docs/STDLIB.md` lists
every helper and the rules a new one must follow.

Gates after BOTH areas (one run, `make doctor true-selfhost gen3 native-test`,
exit 0): `DOCTOR-OK: core tool set is complete`,
`=== TRUE-SELFHOST-MIN-OK ===`, `[OK] byte-identical gen3 == gen4` /
`=== GEN3-OK ===`, `=== NATIVE-TEST-OK ===`. Focused logs:
`docs/logs/seed-for-untyped.log`, `docs/logs/seed-for-fields.log`,
`docs/logs/stdlib-modules.log`.

Current compiler SHA-256 (`selfhost/compiler_min.sa`, after the two gen2 fixes
in this increment):
47503b07d5458c9d01d3e8b7224b39be54a8caf27d0023f3ec9e8fc4d42d59ee
The checked-in offline bundle in `selfhost/compiler_min_gz/` still encodes the
PREVIOUS source (109 parts, sha256 7ca320d5...); it is regenerated with
`make pack-compiler` and the part count recorded here when the compiler source
settles. `restore-compiler`'s fast path uses the checked-in plain source, so the
bootstrap does not depend on the bundle being current.

### Index expressions in the self-hosted compiler, and an honest full-language claim (2026-10-13)

Two things moved: a real language feature was added to the Sayanox-written
compiler source, and the documents that described a full-language path that
does not exist were corrected.

**1. An index is a numeric expression.** `selfhost/compiler_min.sa` gains one
helper, `raw_index(source, from, n) -> str`, in the leading block of `make`
definitions, and four call sites use it: the two copies of the value-position
parser and the two copies of the postfix-operand parser (the operand parser is
why `xs[i] + xs[i - 1]` failed while `xs[i - 1]` alone worked). The condition
rewriter and the `for`-bound rewriter each gained their own lowering, because
they copy text rather than call the expression parser. A declared list becomes
`sx_lget(NAME, IDX)` and a declared string becomes `sx_idx(NAME, IDX)`; both
runtime helpers already took a `double` and truncated it, so no runtime change
was needed. Before this increment gen2 refused every index that was not a
literal or a plain name, and copied an index inside a condition or a bound
verbatim, which produced C that subscripted an `sx_list` struct with a double
(`array subscript is not an integer`).

`make test-gen2-index-expr` pins it: 39 hand-computed values from
`selfhost/gen2_index_expr_test.sa` must be byte-identical on seed-min, gen2 and
native, covering literal/name/parenthesised/field indexes, string indexes,
indexes in conditions, indexes in `for` bounds, indexes on both sides of a
binary operator, and indexes inside typed function bodies; five `grep`
assertions check the emitted C actually contains the lowered calls; and 13
malformed index programs must produce a `min:` diagnostic and a `#error` in the
generated C rather than invalid C. Refused on purpose, each with the workaround
named in the message: `%`, any call including `len()`, a nested index, a comma,
a quoted string, an empty index, unbalanced parentheses and a trailing
operator. `xs[]` used to reach C as `sx_lget(xs,)`; it is now a clear refusal.

**2. The full-language self-host documents were false, and are now honest.**
`docs/FULL_LANGUAGE_SELFHOST.md` told the reader to run
`./selfhost/bootstrap_full_language_selfhost.sh` and expect
`FULL-LANGUAGE SELF-HOST OK`; `docs/FULL_SELFHOST.md` told them to run
`./selfhost/restore_stage2.sh` and `make stage2`. Measured on 2026-10-13: no
such scripts exist, there is no `stage2:` target in the Makefile,
`selfhost/stage2_template.c` is a 93-byte placeholder comment,
`selfhost/stage2_src/` is a README plus an 11-byte placeholder,
`selfhost/sxc_full.c` is a 30-line toy that lowers only `hold NAME = <digits>`
and `show`, and `bash selfhost/restore_stage2.sh` exits 1 with
`error: missing Stage-2 seed`. So there is **no Stage-2 C host that lowers the
full grammar**, and no claim of one survives:

* `docs/FULL_LANGUAGE_SELFHOST.md` was rewritten around what is actually gated
  (the C seed, the Sayanox compiler source, gen1_min -> gen2 -> gen3 -> gen4
  with `gen3 == gen4` byte-identical, and `native_aot`), with a per-feature list
  that names the gate for each line, the refusals, and the measured absence of
  the Stage-2 host.
* `docs/FULL_SELFHOST.md` keeps its history but its two command blocks were
  replaced with the commands that exist.
* 24 legacy documents (`docs/STAGE1..STAGE19`, `docs/FULL_SELFHOST.md`,
  `selfhost/README.md`, `selfhost/SELFHOST.md` and others that advertised the
  same missing entry points) carry a banner stating exactly which entry points
  do not exist and what the supported path is.
* `make test-doc-claims` (wired into `test-stage2`, `test-for-str` and the
  `true-selfhost-min` aggregate) fails if a document advertises a missing entry
  point without the banner, if `stage2_template.c` stops being a placeholder, if
  `restore_stage2.sh` starts succeeding, or if a `stage2:` target appears — in
  which case the docs are the thing that must be updated.

Two constraints on editing the compiler source were found the hard way and are
recorded in `docs/FULL_LANGUAGE_SELFHOST.md`: a `make` definition placed after
top-level statements is not parsed as a definition (gen1_min emitted
`raw_index(double source, double str, double from, double num, double n,
double num)` and gen2.c did not compile until the helper moved into the leading
block), and a scan name shared by two blocks must be declared at the top of the
file, because a first `hold` inside a block becomes a C local of that block
only.

Not claimed: gen2 is not a full-language compiler. A bare string `+` chain in a
`give` still does not compile, `%` and calls inside an index are refused, a
global read inside an untyped `make` is refused, native still rejects a unary
sign in an index and does not wrap a negative one, and generic structs with
concrete layouts and type identities remain unimplemented. The increment is one
feature plus one honesty correction, both gated. (Later the same day the bare
string `+` chain in a `give` and `len()`/a nested index inside `[ ]` were fixed
too, and `%` plus a call other than `len()` inside an index remain refused —
see "Gen2 expression lowering" below.)


---

## Seed memory management measured, and the full seed can compile an operator again (2026-10-13)

Item 3 of the roadmap asked for a real collector subset in the seed **or** a
documented no-GC seed plus a stress test. Measuring first produced the second
answer for one seed, a correction for the other, and a bug fix that was hiding
behind both.

**The full seed could not compile a comparison.** `sxc_seed`'s lexer pushed
single-character operator tokens with the macro

```c
#define P1(ch,k) if(c==ch){ i++; col++; ptok(k,(const char*)#ch,0,sl,sc); continue; }
```

`#ch` stringizes the *argument as written*, quotes included, so `P1('*',T_STAR)`
recorded the three-character text `'*'`. `emit_expr` compares that against
`"*"`, matched nothing, and fell through to the tail of its `E_BIN` case: it
printed the two operands and a closing paren with no operator and no opening
call. `show 2 * 3` became `sx_show(((double)2LL),((double)3LL)))` and
`while i < 3` became `while(sx_truthy(x0,((double)3LL))))` — every program with
arithmetic, a comparison or a loop condition failed to compile. The fix builds
the one-character text from the value (`char ob[2]={(char)(ch),0}`), the idiom
the "unexpected character" diagnostic in the same loop already used;
two-character operators were pushed with explicit strings and were always
correct. `selfhost/seed_gc_ops.sa` now prints `6 5 4 2.5 2 9 0 1 2` on the full
seed, seed-min and gen2 alike.

A 2026-10-04 audit note in the Makefile had declared this area fine ("P1 is only
instantiated with single-char punctuation literals, so `#ch` already stringizes
correctly"). That note was wrong, and because the `fix-seed` awk guard it
described never matched, nothing ever tested it. The note is corrected in place
and `make verify-seed` now fails on a checkout that still has the old macro.

**Seed memory, measured.** `make test-seed-gc` runs five fixtures
(`selfhost/seed_gc_{churn,grow,retain,ops,tmp}.sa`) through seed-min, gen2 and
the full seed under `ulimit -v` caps — 4 MiB is the floor for a dynamically
linked binary, below it `libc.so.6` cannot be mapped:

| fixture | seed-min, 4 MiB cap | gen2, 16 / 64 MiB cap | full seed, 64 MiB cap |
| --- | --- | --- | --- |
| 200k concat churn, nothing retained | `200000` | segfault → now `sx: out of memory` / `200000` | `200000` |
| 2000 concats into one 2003-char string | `2003 97 120` | `2003 97 120` (8 MiB cap is enough) | `2003 97 120` |
| 20 doublings, 8388608 bytes live | exits 1, `sx: out of memory`, stdout `before` kept | exits 1 / `before 8.38861e+06 after` | `before 8388608 after` |
| 2000 temp concats, `SX_GC_DEBUG=1` | no counter exists | collector: `gc_runs()` ≥ 1, `gc_live()` small | **6000 objects still alive at exit** |

So: **seed-min is documented no-GC**, and the two mechanisms that keep it flat
are now written down and pinned — `concat`/`chr` results carry a hidden `sx_sb`
`{magic,len,cap,data[]}` header so repeated concatenation onto the same
left-hand side grows in place, and a string assignment is emitted as
`{ char *_v = sx_cat(a,b); sx_sb_free(a); a = _v; }`, which frees the old
left-hand side after evaluating the right-hand side. Everything else leaks, and
`gc()`/`gc_live()`/`gc_runs()` are refused at compile time rather than silently
returning 0. **The full seed's reference counts do not release in loops**:
three objects per iteration stay registered, memory grows with total allocation
rather than with the live set, `gc()` is a documented no-op returning `0`, and
`gc_live()`/`gc_runs()` do not exist there. That is recorded as the honest state
in [`GC.md`](GC.md) §2 rather than fixed.

**gen2 no longer segfaults under memory pressure.** Its emitted runtime ignored
the results of its own `calloc` (the block hash table, two calls) and `malloc`
(the sweep's sort array and each new block), so a capped run dereferenced NULL
and died with SIGSEGV — exit 139 and no diagnostic. All three sites now print
`sx: out of memory` to stderr and exit 1; the target asserts the three checks
are present in the generated C. Measured alongside it: gen2's first collection
only fires at 8 MiB of managed heap (`sx_gc_thresh` starts at `8u << 20`, then
`live * 1.5 + 4 MiB`), which is why a churn that native runs inside 4 MiB needs
64 MiB here. That threshold is a constant in the emitted runtime and is not
tuned by this increment.

Two smaller seed corrections ride along: `selfhost/seed/sx_runtime.h` now
includes `<stdarg.h>` itself (the seed emits a variadic `sx_lit_list` into every
file, and with GCC 14's defaults a missing prototype is a hard error — the
`-include stdarg.h` workaround is gone from `tools/test-http-get.sh`), and its
pointer to the nonexistent `docs/MEMORY.md` now names `docs/GC.md`.
`make verify-seed` asserts both.

Not claimed: neither seed has a collector; the full seed's release path is
measured broken and left documented; the full seed still needs ≥ 64 MiB of
address space for its static 2097152-entry object table, still needs `-lm` after
the sources when a program uses `%`, and still prints `8388608` where the other
three backends print `8.38861e+06` — all three are pinned by the test, not
fixed. The bootstrap path is unchanged in behaviour: seed-min emits the same C
as before, and gen2's generated code differs only by the three allocation
checks.

---

## Generic-struct refusals, opt-in packages, a multi-document LSP, and the native emit seam (2026-10-13)

Four roadmap items in one increment: the type-system item (7), online packages
(5), the LSP product path (6) and the native platform item (2). None of them
changes the bootstrap dialect, and all four are gated.

### 7. Generic structs: the refusal is now the feature

Generic structs are still **not implemented** — no type identity, no
per-instantiation layout, no specialization worklist
([`TYPES_ROADMAP.md`](TYPES_ROADMAP.md) lists the five prerequisites). What
changed is that the three backends now say so, instead of reporting a symptom of
their own parser:

| Backend | Before | Now |
|---|---|---|
| seed-min | `seed_min: { at 10` — a brace, at a *character offset* | `generic structs are not implemented: a struct declaration cannot take a type parameter list, so declare a concrete struct name (docs/TYPES_ROADMAP.md)`, exit 1, from all four scan paths that see a struct declaration |
| gen2 | `min: undefined name: Box` for `Box<num> { 1 }`, and `min: struct literal must fill every field` for `Box { 1 }` — wrong about the program the user wrote, because `<T>` was swallowed into the field list | the same sentence on stdout **and** `#error sayanox-min: generic structs are not implemented: …` in the generated C |
| native | `native_aot: struct Box needs { fields }` | `native_aot: generic structs are not implemented: struct 'Box' cannot take a type parameter list, …`, exit 1 |

`make test-generic-structs` pins those three diagnostics, pins the supported
workaround (`selfhost/generic_struct_concrete.sa`: `NumBox`, `TextBox` and
`PairBox` in one program — `7 seven 8 eight 2 8 9`, byte-identical on all three
backends), and pins one divergence found while writing it: a **dotted field read
inside a struct literal** (`hold a2 = NumBox { a.v }`) is accepted by seed-min
and refused by gen2 (`#error … literal value must be a number, string, name, or
nested struct`) and native (`field 'NumBox.v' is used with two different
types`). Refused, not miscompiled — and the portable spelling (`hold v = a.v`,
then `NumBox { v }`) is in the fixture's comment.

### 5. Online packages are opt-in, and both online targets are gated

`SAYANOX_REGISTRY` used to be both the *where* and the *permission*: with the
default registry URL, `sxpkg sync`, `sxpkg install` and `sxpkg fetch` simply
reached for the network. They now refuse first:

```sh
sxpkg: refusing to use the network without an explicit opt-in
sxpkg:   target: https://registry.invalid/r
sxpkg: opt in with SAYANOX_ONLINE=1, or 'sxpkg --online <command>'.
sxpkg: offline instead: install-local, seed, verify, list, deps, info,
sxpkg:   or point SAYANOX_REGISTRY at a local directory (file://...).
```

Permission is `SAYANOX_ONLINE=1` or `sxpkg --online <command>`. A `file://` URL
or a plain local path is not the network and never asks, and `install` decides
per package: a locked package whose `pkg.meta` **and** `main.sa` are already
local is copied and verified offline even when the registry URL is remote — only
a genuinely missing package asks. `download()` is now bounded
(`curl --connect-timeout 10 --max-time 60`, `wget --timeout=10 --tries=1`), so a
host that accepts and then goes quiet cannot hang a build. `publish` still never
uploads, with or without an opt-in: going online is a commit to
`registry/<name>`, which is a review step, not a client command.

`make test-sxpkg-online-optin` asserts all of it, and `make
test-sxpkg-online-local` (which existed but was on no gate) is now in both
aggregates. Neither target opens a socket: the online path is exercised against
a `file://` registry, and the opt-in path against `.invalid` host names (RFC
2606), which fail in the resolver. Both skip cleanly if neither `curl` nor
`wget` exists. Still not claimed: signatures, a cryptographic hash, version
ranges, upload.

### 6. The LSP keeps four documents, and answers each from its own buffer

The server kept ONE document. A second `didOpen` overwrote it, so with two
Sayanox files open every request for the first was answered from the second's
buffer — a wrong answer, not a missing one. `didChange` was guarded against a
foreign URI; `didOpen`, `hover`, `definition`, `documentSymbol` and
`textDocument/diagnostic` were not.

It now keeps a four-slot table. The dialect has no array of strings, so the
table is four parallel pairs of globals (`uri0`/`txt0` … `uri3`/`txt3`) and
exactly three places touch it: a load cascade under the framing loop, `didOpen`
(store) and `didClose` (clear). Every message reloads `doc`/`docuri` from its own
`params.textDocument.uri` before the handlers run, so the readers are unchanged
and each answers from the buffer the client asked about. A request for a URI
that is not open gets an empty document and therefore an empty answer
(`documentSymbol` → `[]`, `diagnostic` → no items), never another file's
contents; `didChange` for an unopened URI publishes nothing; a **fifth**
`didOpen` evicts the slot that has been open longest, and the evicted document
stops being served until it is opened again. That cap is a documented limit, not
a claim about editor sessions.

`tools/sayanox-lsp-probe.sh` now drives three sessions and `make test-lsp`
asserts eighteen lines instead of thirteen: two documents open at once with the
first still served after the second was opened, a closed document answering
`"result":[]` and not being served from another buffer, and the five-document
eviction (`f1` gone, `f5` served). Still not implemented: `workspace/symbol`,
references, rename, formatting, and any cross-file analysis.

### 2. Native: an emit seam, not a second target

`native_aot.c` is a single-pass compiler — it parses and emits in the same walk
— so a second target cannot mean swapping a file, and none is claimed. What now
exists is a seam: the machine-specific half of the file is delimited, and the
language half provably does not touch it.

* Everything that writes bytes lives in the `x86-64 mini encoder` region above
  `phase 1`, and the API gained five named primitives for the sequences the emit
  tree used to write itself: `here()` (a label position), `patch_imm32()`,
  `leave_ret()`, `sub_rsp_imm32_slot()` and `jmp5_slot()`.
* The language-level emitter is bracketed by `EMIT-SEAM-BEGIN` /
  `EMIT-SEAM-END`: 1302 lines, no `e1(`/`e32(`/`e64(`, no `memcpy` into `code`,
  and no direct read of the cursor `cn` (28 of them became `here()`). A
  hand-rolled rel32 patch that duplicated `erel32j` is gone.
* Below the end marker the file is x86-64 again by nature — the phase-4 runtime
  stubs, the collector and the ELF container — and [`NATIVE.md`](NATIVE.md)
  records the two contracts a replacement backend inherits: the System V AMD64
  calling convention the emit tree assumes, and the collector's block layout.
* The refactor was verified **byte for byte**: six fixtures emit executables
  that `cmp` clean against the binaries produced by the pre-seam `native_aot`.
  `make test-native-emit-split` keeps the region clean and runs one program end
  to end.

Two honesty corrections ride along. `docs/NATIVE.md` described the native IR
boundary through `parse_prim`, `parse_term`, `parse_expr`, `estmt` and `eblk` —
five functions that do not exist in the file; the emit tree is `emit_prim` →
`emit_post` → `emit_term` → `emit_rel` → `emit_expr` under `emit_prog`/`emit_fn`.
And the build's last warning is gone: `emit_prim` (void) had a `return <value>`,
while the identical line in `pk_prim` (int) is correct and was left alone.

### Gates

`make doctor && make true-selfhost && make gen3 && make native-test` passed
after each of the four items and once more, chained exactly like that, at the
end. The four logs of the final run are
[`docs/logs/four-items-doctor.log`](logs/four-items-doctor.log) (`DOCTOR-OK`),
[`docs/logs/four-items-true-selfhost.log`](logs/four-items-true-selfhost.log)
(`TRUE-SELFHOST-MIN-OK`, 886 lines),
[`docs/logs/four-items-gen3.log`](logs/four-items-gen3.log) (`GEN3-OK`,
including `[OK] byte-identical gen3 == gen4`, which is the check that the
compiler's own source edits did not move its fixed point) and
[`docs/logs/four-items-native-test.log`](logs/four-items-native-test.log)
(`NATIVE-TEST-OK`, 103 `[OK]` lines). The earlier seed-memory run of the same
chain is `gates_item3` in the same directory. The three new targets (`test-generic-structs`,
`test-sxpkg-online-optin`, `test-native-emit-split`) plus the two newly gated
ones (`test-seed-gc`, `test-sxpkg-online-local`) are wired into the
`true-selfhost-min` and `native-test` aggregates as appropriate — the native one
only where `native_aot` is built.

Not claimed: generic structs, a second native target, a workspace-aware LSP,
signed or uploaded packages, or any change to the pure-min bootstrap dialect.
(The LSP row is now narrower: references, workspace symbols and formatting
landed later the same day — see below. A workspace *scan* is still not claimed,
because the dialect has no directory-listing builtin.)


---

## Gen2 expression lowering: a string chain in a `give`, and `len()` or a nested index inside `[ ]` (2026-10-13)

The two gen2 gaps that were still recorded as open divergences are closed in the
self-hosted compiler source (`selfhost/compiler_min.sa`), and both are gated by
one new target, `make test-gen2-expr-lowering`, wired into the
`true-selfhost-min` and `native-test` aggregates. Nothing changed in the
pure-min bootstrap dialect, in seed-min, in the full seed or in `native_aot`:
this increment only removes two places where gen2 was the odd backend out.

### The `give` that could not join two strings

`give "hi " + name` inside a function body was copied into the C as
`return "hi " + name;`, which cc rejects with `invalid operands to binary +
(have 'char *' and 'char *')`. The same chain in a `hold` always worked,
because the value-position parser joins two strings through `sx_cat`. The
expression rewriter that feeds a `give`, a `when`/`while` condition and a
parenthesized expression now does the same:

* it already scanned back over the left operand and forward over the right one
  to lower `%` through `sx_mod`; that handler now covers `+` as well, and the
  back-scan also walks over a quoted literal (counting the backslashes before a
  quote, so an escaped `\"` does not end the walk early);
* `str_operand(text, sdecls)` decides whether an operand is a string: a quoted
  literal, an `sx_cat(...)` group, a name in the string declaration table
  (`sdecls`, which holds `str` parameters and `for` variables too), or a call
  to a builtin that gives a string (`concat`, `chr`, `numstr`, `arg`,
  `read_line`, `read_n`, `read_file`, `http_get` and their `sx_` names). Spaces
  left by the scans are trimmed before the table lookup;
* both strings → `sx_cat(L, R)`, nested for a chain, so `"x" + n + "y"` becomes
  `sx_cat(sx_cat("x" , n) , "y")` and `concat(p, q) + "/" + p` becomes
  `sx_cat(sx_cat(sx_cat(p, q) , "/") , p)`;
* exactly one string → refused with the value parser's own sentence, `+ joins
  two strings or adds two numbers; the other side of 'v' is not a string (bind
  it with hold first)`, as a `min:` diagnostic on stdout and a `#error` in the
  C. seed-min refuses the same program, so the backends agree on the diagnosis;
* `%` with a string operand is refused too (`'%' truncates two numbers; one of
  its operands is a string`), which seed-min and native already did.

A struct string field (`give "n=" + p.name`) and a call to a user function that
gives a string are *not* classified as strings by `str_operand`, so those two
forms are refused rather than mis-compiled; binding the value with `hold` first
works everywhere, as before.

`selfhost/gen2_str_cat_test.sa` is 11 hand-computed values — literal + name,
name + literal, a three-part chain, an escaped quote inside a literal, a call
operand, a chain in a `hold` inside a typed body, and a string comparison in a
condition — byte-identical on seed-min, gen2 and native, with the emitted
`sx_cat` forms pinned by `grep`.

### `len()` and a nested index inside `[ ]`

`xs[len(xs) - 1]` was refused in a value position (`unsupported index
expression`) and copied verbatim into the C in a condition and in a `for`
bound, where cc reported `array subscript is not an integer`. Two helpers in
the leading definition block fix every position at once:

* `tbl_has(table, name)` answers whether a `|name|name|` declaration table
  holds a name — the tables belong to the main loop and a helper cannot
  capture them, so they are passed in;
* `idx_lower(text, ldecls, sdecls)` lowers index text into C: `len(NAME)` to
  `sx_llen`/`sx_len` and `NAME[IDX]` to `sx_lget`/`sx_idx`, each chosen by the
  declaration tables, recursing into a nested index, and copying numbers,
  names, dotted field chains, parentheses and `+ - * /` verbatim (which is
  already valid C). It gives `""` when it cannot lower — `%`, a call other than
  `len()`, a quoted string, a comma, a stray bracket, a name declared neither
  list nor string — and every caller keeps its existing refusal then.

`raw_index` now copies a call and a nested `[...]` verbatim instead of refusing
them, tracking bracket depth so the closing `]` of the outer index still ends
the scan. Copying verbatim matters: a caller advances its own cursor by `len()`
of the result, so the text and the position have to stay in step, and the
lowering happens where the C is emitted. `idx_lower` is wired at the four
value-position call sites (the two value parsers and the two postfix-operand
parsers), in the condition rewriter's index path and in the `for`-bound
rewriter, so all of these now work in gen2:

```
xs[len(xs) - 1]        xs[len(xs) - len(ys)]   xs[ys[0]]      xs[ys[1] + 1]
s[len(s) - 2]          when xs[len(xs) - 1] > 39              for k in 0..ys[len(ys) - 1]
make pick(v: list) -> num { give v[len(v) - 1] }              show xs[i + 1] + xs[len(xs) - 1]
```

`selfhost/gen2_index_call_test.sa` is 18 hand-computed values covering exactly
those forms, byte-identical on seed-min, gen2 and native, with the emitted
`sx_llen`/`sx_len`/`sx_lget`/`sx_idx` forms pinned by `grep` in a value, a
condition, a `for` bound and a typed body.

Still refused inside `[ ]`, each with a `min:` diagnostic and a `#error` rather
than invalid C: `%`, a call other than `len()` (so `xs[pick(xs)]`, which
seed-min and native do accept — that row stays open as a narrower divergence),
a quoted string, a comma, an empty index, unbalanced parentheses or brackets,
and an expression that ends with an operator. `make test-gen2-index-expr` keeps
its 39 values and now pins 9 refused forms instead of 13; its five
`len()`/nested-index refusals moved to the new target as positive parity
checks.

### Two lessons this increment re-learned the hard way

* A `hold` name may be declared only **once per generated C function**, and the
  whole main compile loop of `compiler_min.sa` is one function. Reusing a scan
  name that another block already declares (`cwq`, `cwb2`) or naming the same
  helper result at two sibling call sites (`ixl`, `opxl`) makes gen1_min emit a
  bare assignment with no declaration, and gen2.c then fails to compile with
  `'NAME' undeclared`. Every new name in this increment is unique to its site.
* The back-scan for an operand has to know which end of a literal it starts
  from: the first version stopped at the *closing* quote, so `"[" + j` emitted
  `"[sx_cat(" , j)`. The fixture that caught it is a three-part chain, which is
  why `gen2_str_cat_test.sa` has one.

### Gates

`make test-gen2-expr-lowering` and the updated `make test-gen2-index-expr` both
pass, including native parity for both fixtures and all 6 + 9 pinned refusals.
The full chain `make doctor && make true-selfhost && make gen3 &&
make native-test` was re-run after the source edits and the offline pack was
regenerated (`make pack-compiler`, 119 parts, round-trip verified against
`selfhost/compiler_min.sa`); the logs are `docs/logs/expr-lowering-*.log`.

Not claimed: a call other than `len()` inside an index, `%` inside an index, a
struct string field or a user-function call as a `+` operand in a `give`,
generic structs, a second native target, or any change to seed-min, the full
seed, `native_aot` or the pure-min bootstrap dialect.


---

## The LSP answers references, workspace symbols and formatting (2026-10-13)

`tools/sayanox_lsp.sa` gained three methods — `textDocument/references`,
`workspace/symbol` and `textDocument/formatting` — all answered from the buffers
the server already keeps, so the four-slot document table, the framing loop and
every existing answer are untouched. `make test-lsp` now asserts 29 facts over
five sessions instead of 18 over three, and the two extra sessions are the new
methods. [`docs/LSP.md`](LSP.md) documents each one.

* **references** — `refs_for(w, text, uri, incl, first)` collects whole-word
  occurrences of the word under the cursor (an identifier run compared with
  `string_eq`, so `zz` does not match inside `fuzzy`) and returns `Location[]`.
  Columns go through the existing `utf16_span` helper twice — the word's byte
  offset and the offset just past its last byte — so a range covers the whole
  word and stays right on a line with accented Latin, Bengali or emoji before
  it. `context.includeDeclaration: false` skips the line whose first non-blank
  text is `make w`, `hold w` or `struct w`; both spellings of the flag (with and
  without the space after the colon) are recognised. A position that is not on a
  word answers `[]`.
* **workspace/symbol** — `symbols(text, uri)` became
  `sym_scan(text, uri, query, first)` and `symbols` delegates to it with an
  empty query, so `documentSymbol` answers byte-for-byte what it always did
  (the probe still pins `"name":"twice"` and `"name":"x"`). A non-empty `query`
  filters by case-insensitive substring through a new ASCII `lower` helper.
* **formatting** — `format_text(text)` is a rule-for-rule port of
  `tools/sxfmt.sa`: indentation rebuilt from brace depth at two spaces per
  level, leading and trailing whitespace stripped, blank lines kept blank, a
  final newline added, braces counted only outside a quoted string (with `\`
  escapes) and outside a `//` comment, a line starting with closing braces
  indented at the depth those braces return to, and tokens and comments never
  rewritten. `format_edit(text)` answers `[]` when the text comes back
  unchanged, so a client leaves a formatted buffer alone, and otherwise one
  whole-buffer `TextEdit` whose end is one past the last newline (or the UTF-16
  width of the last line when there is none), with `newText` through the
  existing `json_esc`. The probe feeds it the same badly indented source that
  `make test-sxfmt` feeds the formatter *program* and asserts the indentation,
  the stripped trailing whitespace and the range — which is what makes "the LSP
  formats like `sxfmt`" a checked claim rather than a comment.

Because a function cannot capture globals in this dialect, the four-slot table
stays unreadable from a helper; both spanning methods therefore cascade in the
dispatch site, one call per slot, and the comma rule lives inside the helper
(`first` is the number of items the caller already has, and `len(res)` is
exactly that at each step). Capabilities advertise `referencesProvider`,
`documentFormattingProvider` and `workspaceSymbolProvider`; the robustness and
Unicode probes still pass unchanged (11 and 7 lines).

Not claimed: a workspace *scan*. `workspace/symbol` and `references` only see
documents a client opened, because the dialect has no directory-listing builtin
and the server does not spawn a process; a file nobody opened cannot be
searched. Also not claimed: rename, code actions, signature help, incremental
sync, or a formatter that rewrites tokens.
