# Status

Last updated: 2026-10-11

## Entry

```bash
make doctor             # -> DOCTOR-OK                log: docs/logs/make-doctor.log
make true-selfhost      # -> TRUE-SELFHOST-MIN-OK     log: docs/logs/make-true-selfhost-min.log
make gen3               # -> GEN3-OK (gen3 == gen4)   log: docs/logs/make-gen3.log
make native-test        # -> NATIVE-TEST-OK           log: docs/logs/make-native-test.log
```

Everything below was verified by running those commands plus the per-feature
targets listed at the end of this file, on this host (3939 MB RAM, 2 CPUs,
x86-64, `/bin/sh` = dash). Nothing in the tables is aspirational. `docs/logs/`
holds the raw output of the four commands above; each run overwrites them, and
they were last regenerated 2026-10-11 (after the LSP error-response, stdlib-growth
and sxpkg-polish additions, and the earlier package, stdlib, native-memory,
Stage-2-demo and statement-parity test additions described below). The
`true-selfhost` log was taken with no `selfhost/native_aot` present, i.e. in the
state a clean checkout is in, and the native half of `test-stage2-demos` prints
an explicit `skipped` line there; `make native-test` builds that binary and runs
the check.

GitHub Actions (`.github/workflows/ci.yml`) runs exactly these four targets —
`doctor`, `true-selfhost`, `gen3`, `native-test` — on a clean `ubuntu-latest`
checkout with no package install and no network: the runner's stock toolchain
is the minimal tool set `doctor` verifies.

## Minimal tool set (re-measured 2026-10-07)

Full audit, measurements and method: **[`DEPENDENCY.md`](../DEPENDENCY.md)**.

The bootstrap needs a host C toolchain and `make` — that is not "zero
dependencies" and is not claimed to be. What it does *not* need is any
interpreted language: no Python, Node, Ruby, Perl, PHP or shell-script process
is ever started on any target, and no such file is tracked in the repository.

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

| Feature | seed-min | gen2 | native | Checked by |
|---------|----------|------|--------|------------|
| numbers, strings, `hold`/`show`/`when`/`otherwise`/`while`/`make`/`give`, lists, structs | done | done | done | `make test-stage2`, `make native-test` |
| string `==` `!=` `<` `<=` `>` `>=` (content compare) | done | done | done (2026-10-10) | `make test-gen2-gaps`, `make test-native-strord` |
| `and`/`or`/`not` in `when`/`while` conditions | missing | done | done | `make test-stage2`, `make test-native-cond` |
| `true` / `false` literals | missing | done | done (2026-10-11) | `make test-native-lang`, `make test-stage2` |
| `elif`, `else if`, `else when` | missing | done | done (2026-10-11) | `make test-native-lang` |
| `for NAME in A..B` (end exclusive) | missing | done | done (2026-10-11) | `make test-native-lang` |
| `for NAME in <list or string>` | missing | done | done (2026-10-11) | `make test-for-str`, `make test-native-lang` |
| `break` / `continue` in `for` and `while` | missing | done | done (2026-10-11) | `make test-native-lang` |
| `gc()` / `gc_live()` / `gc_runs()` | missing | done | done | `make test-native-mem` |
| generics `make f<T>(...)` | refused | done (monomorphised) | missing | `make test-generics` |
| `and`/`or`/`not` as values (`hold v = a and b`, `show a or b`) | missing | missing | refused by name | not added: gen2 refuses them too, and the language docs define them only in conditions |
| `hold` inside a `make` body | done | done | done (2026-10-11: a slot in the call's own frame; `make test-native-locals`) |
| typed list elements and typed `make` signatures | missing | missing | missing | deferred: needs a design decision (list element type, arity and return type rules) |

Still open on native, besides the deferred rows: nothing in the pure-min
statement set is missing. Generics need a native monomorphiser; `hold` in
`make` needs stack frames.

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
| full-language statements (`for`, `break`, `continue`, `elif`, `for c in <string>`, `and`/`or`/`not`, ...) | error: `unknown statement` | yes: `for` over strings **and lists** (a variable, a list literal, a string literal or a call), nested loops, `break`/`continue` in both, `elif`/`else when` chains, `and`/`or`/`not` with `not` binding looser than a comparison, `true`/`false`, plus the generics/`use` extensions | yes for `for` over a range `0..N`, over lists and strings, `break`/`continue` in `for` and `while`, `elif`/`else if`/`else when` chains, `and`/`or`/`not` in `when`/`while` conditions, `true`/`false` (2026-10-11, `make test-native-lang`, `make test-native-cond`); still refused by name: `and`/`or`/`not` as values, `generics` (see roadmap) |
| diagnostic wording | own text (`seed_min: ...`) | own text (`min: ...` / `#error` line) | own text (`native_aot: ...`) |
| host and memory | any C host, malloc-based, no collector | any C host, mark & sweep | x86-64 Linux only; own heap (first-fit + bump) with a mark & sweep collector (corrected 2026-10-10; was "bump-allocated, never freed") |

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
  The full-language statements `for`, `break`, `continue` and `elif` are
  on gen2 and native (native since 2026-10-11, `make test-native-lang`).
  seed-min reports `unknown statement` for them (`make test-for-str`).
* **Stage-2 slice (2026-10-08): `for c in <string>` on gen2.** A declared
  string is walked one byte at a time, each iteration binding `c` to a
  one-byte string. `break`, `continue`, nesting, the empty string, a counter
  that rebinds across loops and a string counter reused for a second string
  all work (`make test-for-str`). Errors are clear: a number or a list as the
  iterated value, and a counter name that is already a number or a list.
  Iteration is by byte, so `"é"` is two iterations. seed-min and native refuse
  the statement. This is one slice of the Stage-2 language, not a claim of
  it: see the gen2 gaps below and "Out of scope".
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
  function is supported in `hold` RHS, `show` and `give`. Native rejects
  `hold` inside a `make` body with a clear error — a local would live in the
  shared data segment and be clobbered by recursion; compute in `give`
  expressions or assign to a top-level global instead. seed-min and gen2
  lower a body `hold` to a real C local.
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
  divergence table (`hold` in a function body, the collector builtins, the
  full-language statements and bump-only memory). Native output is x86-64 Linux only. The runtime
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
| `make test-lsp` | the Sayanox language server in a live JSON-RPC session (probe written with shell builtins + `mkdir` only): initialize/serverInfo, didOpen + publishDiagnostics, SX1001/SX1002/SX1003/SX1005 diagnostics, documentSymbol (function + variable), completion (builtin names survive in string literals), hover, definition, and a didChange that clears the diagnostics |
| `make test-generics` | two legs. (a) single type parameter: `make NAME<T> ... -> T` — 14 lines of a program mixing `pickb`/`twice`/`quad` over num, str and list print identically under gen2 and gen1_min; each `NAME__n/s/l` appears exactly once, every call sees a prototype, an unused generic emits nothing. (b) **multi-parameter**: `pair<A, B> -> A`, `swap<A, B> -> B`, `three<A, B, C> -> C` and `usefirst<A, B>` (which calls `pair` and binds the result with `hold`) over `nn`/`ns`/`sn`/`ls`/`ln`/`sl`/`nsl`, each copy asserted exactly once, per-parameter C types checked, no `#error`, no implicit declaration, and gen1_min output **byte-identical** to gen2; two rejection cases (a parameter that does not use a type parameter, a return type naming an undeclared one) |
| `make test-gc` | gen2 mark & sweep from the language side: a 2000-iteration `concat` loop stays under 200 KB of live heap after `gc()`, `gc_runs()` counts a collection, `gc()` reclaims bytes, and the surviving string is intact (`len` + first byte) |
| `make test-native-io` (part of `native-test`) | native `read_file`/`write_file`/`arg`/`arg_count` give the same results as seed-min and gen2 (argv[0] counted, truncating write returns 1, missing file reads as `""`, 160 KiB round trip) |
| `make test-native-mem` (part of `native-test`) | native memory with a real collector: a string doubled to 262144 bytes is served whole; 100000 `push`es keep every value; a 200000-iteration churn loop (~8 MB allocated, nothing retained) **finishes inside a 4 MiB `ulimit -v` cap** running 200+ collections; `gc_runs()` > 0, `gc()` reclaims bytes and `gc_live()` reports a positive live count; strings, list elements and struct fields survive 30000 allocating iterations; a program that genuinely retains 8 MiB still exits non-zero with stdout written before the failure kept and `out of memory` on stderr. See [`GC.md`](GC.md). |
| `make test-stage2-demos` | the three Stage-2 contract demos (`minimal_lexer`, `stage2_functions`, `stage2_variables`) compile byte-identically under seed-min and gen2; the string-only one also runs natively when `native_aot` is built (the native half is skipped, loudly, on the portable `true-selfhost` path, and executed in `make native-test`) |
| `make test-stage2` | the Stage-2 slice beyond the string walk on gen2: `and`/`or`/`not` precedence (asserted on the emitted C: `if (!(a == 2.0) && b == 0.0)`) and short-circuit (two `10 % 0` guards would abort if the right-hand side were evaluated), `true`/`false`, `for` over a list variable / list literal / string literal / call returning a list / call returning a string, nested loops, `break`/`continue` in a list loop, an `elif` chain, `and` inside a `while` condition; gen1_min output byte-identical to gen2, seed-min refuses the program, native names `for`/`and`/`not`/`true` |
| `make test-stdlib` | `stdlib/tiny.sa` spliced with `use`: 30 numeric helpers (`min2`/`max2`/`absv`/`sum_to`/`pow_int`/`is_even`/`gcd`/`clamp`/`sign`/`is_odd`/`lcm`/`fact`/`fib`/`is_prime`/`sum_range`/`sum_sq`/`count_digits`/`digit_sum`/`trunc10`/`reverse_num`/`is_square`/`between` and their recursion workers) give the same answers on seed-min, gen2 and (when built) native; a second leg runs `str_util.sa` + `list_util.sa` + `file_util.sa` on gen2 (34 assertions over 34 string/list/file helpers) and proves seed-min and native **refuse** those files instead of miscompiling them |
| `make test-pkgs` | the offline package path: `sxpkg.sh init`+`seed` write `.sayanox/registry/{hello,math,strings}` with no network, `sxpkg add` records the lock, a program with `use \".sayanox/registry/math/main.sa\"` runs the same on seed-min, gen2 and native, and `sxpkg verify` passes on a clean project, reports the tampered `main.sa` as a `sum` MISMATCH, and passes again after the re-seed. **Plus the dependency path** on `registry/calc` (`deps=math@0.1.0`): `add` locks the closure and prints a line per package, the lock is compared byte for byte, `deps` prints the closure, a bare `install` reports `cannot write .sayanox/registry/<name>/`, `sh tools/sxpkg.sh install-local registry` installs both sum-checked, `verify` reports both, `use \".sayanox/registry/calc/main.sa\"` prints `36`/`25` identically on seed-min and gen2, and the `not in sx.lock` / `but sx.lock has` errors are asserted |
| `make test-gen2-gaps` | string `<`/`<=`/`>`/`>=`/`==`/`!=` by content on gen2 and seed-min, and native since 2026-10-10 (same output; string vs number is an error on seed-min); the gen2 fixes of 2026-10-08: `len(NAME)` in a range bound (list `sx_llen`, string `sx_len`); string `==`/`!=` between declared strings as strcmp (two equal runtime strings compare equal); `} else when`, `} else if` and `} otherwise when` chains including nested ones, with the same output as `elif`; seed-min and native refuse the chains; `%` inside builtin-call arguments is sx_mod, same as seed-min. |
| `make test-registry-sums` | every `pkg.meta` `sum=` in the repository equals `sxpkg sum` of its `main.sa` (offline integrity; see [`REGISTRY.md`](REGISTRY.md)) |
| `make test-for-str` | the Stage-2 slice on gen2: `for c in <string>` byte walk, vowel count with `string_eq`, `break`/`continue`, empty string, nested loops, a rebound counter, `\"é\"` as two bytes, the diagnostics for a number, a list and a counter clash; seed-min refuses the statement; native names it; a `make NAME<T>` whose second parameter is not a type parameter is refused with the generic diagnostic. |
| `make native-test` | native subset, one slot per name, undefined names, list ops + push/grow + bounds, structs, nested structs (2 and 3 levels, typed copy incl. doubly nested, seed-min/gen2 output parity), `use` splice (depth 2, input-dir resolution, missing-file and unquoted-path errors), functions (recursion `fac`/`fib`, 6 params, forward refs, mutual recursion, zero-arg, global assignment, builtin and string args), postfix right of `* / %` + left-assoc, string `s[i]`/`sx_index`, `else`/`otherwise` false branch, unsupported constructs rejected (incl. hold-inside-make, give-outside, make-in-block, wrong arg count/type, non-numeric give) |

## Roadmap: done vs still missing, per backend (synced 2026-10-11)

This table replaces the 2026-10-08 roadmap. Every "done" cell names the gate
that checks it; a "missing" cell says why it is missing. "n/a" means the thing
does not exist on that backend by design (not a gap that is being hidden).

The three backends are `seed-min` (the C seed, `selfhost/seed/sxc_seed_min`),
`gen2` (the compiler built by `gen1_min`, which is what `true-selfhost`
ships) and `native` (`selfhost/native_aot`, x86-64 Linux only).

| Area | seed-min | gen2 | native | Gate(s) | Still missing |
|---|---|---|---|---|---|
| Pure-min core: numbers, `when`/`while`, `make`/`give`, recursion, lists, structs, `use` | done | done | done | `true-selfhost`, `native-test` | none in the shared dialect |
| Numeric stdlib `stdlib/tiny.sa` (36 `make` definitions: 25 before this pass, +9 public numeric helpers and +2 internal ones added 2026-10-10: `tri`, `min3`, `max3`, `ceil_div`, `pow_mod`, `collatz_steps`, `digit_at`, `is_palindrome`, `isqrt`) | done | done | done | `test-stdlib`, `test-stdlib-growth` (hand-computed values; seed-min == gen2 byte for byte), and the native leg in `native-test` | more helpers only when they fit the native subset (no `hold` in a body, at most 6 parameters) |
| String / list / file stdlib (`str_util`, `list_util`, `file_util`) | refuses (typed parameters) | done | refuses (`bad param list`) | `test-stdlib` | by design gen2-only until typed parameters exist on the other two |
| Generics `make NAME<T>` / `make NAME<A, B>` | refuses (`make NAME<...>` is not read) | done (one or more parameters, monomorphised) | refuses (`generics are not in the native subset`) | `test-generics`, `test-native-*`, `test-stage2` | seed and native generics are **not** implemented. Parity here means *the same refusal*, which is tested. Adding it to the seed changes the fixed-point root and to native needs a monomorphiser; neither is safe in this pass |
| Full-language statements: `for` (strings and lists), `break`, `continue`, `elif`, `and`/`or`/`not`, `true`/`false` | refuses (`unknown statement`) | done | `for`, `break`, `continue`, `elif`, `true`/`false` refused by name; `and`/`or`/`not` and parentheses **work in `when`/`while` conditions** (short-circuit jumps, added 2026-10-11) but are still refused by name in value expressions (`show a and b`) | `test-stage2`, `test-for-str`, `test-gen2-gaps`, `test-native-cond` | seed: none of these (the pure-min set). Native: `for`/`break`/`continue`/`elif` and value-position `and`/`or`/`not`/`true`/`false` are still missing (deliberately; the native subset is pure-min plus conditions) |
| Stage-2 demos (`minimal_lexer`, `stage2_functions`, `stage2_variables`) | done | done | done (lexer) | `test-stage2-demos` | these are contract sketches, not a full Stage-2 compiler |
| String ordering `<` `<=` `>` `>=` (byte order, in `when`/`while` conditions) | done | done | done (`B_STRORD`, added 2026-10-10) | `make test-native-strord` (same output on all three; long shared-prefix case checked against gen2) | Value-form comparisons (`show a < b`, `hold r = a < b`) are rejected by gen2 (`unexpected '<'`), so the test uses conditions only. Not a full collation: byte order only |
| Collector `gc()` / `gc_live()` / `gc_runs()` | refuses (no collector in the seed runtime) | done (mark & sweep) | done (native mark & sweep, `docs/GC.md`) | `test-gc` (same program, same output on gen2 and native), `test-native-mem` | native is non-compacting and its stack scan is conservative, so it may retain garbage |
| `hold` inside a `make` body | done | done | **missing** — rejected with a clear error | `test-native-*` (the rejection) | **Deferred (item 7).** A native local lives in the shared data segment and recursion clobbers it. Doing it safely needs stack frames in the native code generator, so it is not done in this pass |
| Richer types | `double`, `str`, list, literal-struct | same, plus generics; no bounds, no generic structs | same as seed-min | `test-generics`, `test-struct2` | **Deferred (item 6).** Typed list elements, bounds and generic structs need a type-checker that does not exist yet. This pass changed no type rules |
| Packages `sxpkg` — offline (`init`, `add`, `list`, `remove`, `seed`, `search`, `info`, `deps`, `install-local`, `verify`, `sum`) | n/a (the tool is a Sayanox program, built by gen2) | done | n/a | `test-sxpkg`, `test-sxpkg-wrapper`, `test-sxpkg-polish`, `test-pkgs`, `test-registry-sums` | the `install-local` / `verify` exit codes come from the shell wrapper (the language has no exit builtin) |
| Packages — online (`sync`, `install`, `fetch`, `publish` over HTTP) | n/a | n/a | n/a | `test-sxpkg-online-local` (file:// registry; not a bootstrap gate) | **Partly done.** Downloads are atomic (`.part` then rename), and a fetched package that fails `verify` is removed. Still missing: signatures and a cryptographic hash (the sum is a 31-multiplier hash), and `publish` upload. Shell only (`curl`/`wget`). The design is in [`SXPKG_ONLINE.md`](SXPKG_ONLINE.md) |
| LSP (`tools/sayanox_lsp.sa`) | n/a | done (diagnostics, symbols, completion, hover, definition, `didChange`, JSON-RPC errors `-32600`/`-32601`/`-32700`) | n/a | `test-lsp`, `test-lsp-robust` | incremental parsing, multi-file analysis (string ids are echoed as sent since 2026-10-11, `test-lsp-robust`) |
| Documentation and logs | `STATUS.md` synced | `GC.md`, `GENERICS.md`, `LSP.md`, `REGISTRY.md`, `STDLIB.md` current | `NATIVE.md`, `GC.md` current | `docs/logs/` regenerated by the four gate commands | `selfhost/STAGE2.md` describes the legacy `restore_stage2.sh` path, which no Makefile target builds (see below) |

### What "Stage-2" means in this repository (checked 2026-10-10)

* The Stage-2 that the gates exercise is the **full-language statement set
  compiled by gen2** (`test-stage2`, `test-for-str`, `test-gen2-gaps`), plus the
  Stage-2 demo programs. It is not a separate binary.
* `selfhost/STAGE2.md` and `selfhost/restore_stage2.sh` describe an older
  `selfhost/stage2` binary. No Makefile target builds or tests it, so it is
  legacy documentation, not a verified state. It is marked as such in that file.
* The bootstrap that is verified end to end is `seed-min → gen1_min → gen2 →
  gen3 == gen4` (`true-selfhost`, `gen3`). A "full" self-hosting compiler that
  compiles the full language is still not built; `true-selfhost-full` says so.

### Corrections made in this pass (were stale)

* Native collector: the divergence table said native had **no** `gc()`
  (`undefined variable 'gc'`) and "bump-allocated, never freed". Both were wrong:
  native has a real mark & sweep collector and `test-gc` checks it against gen2.
  Probed on 2026-10-10: `gc()` prints `1` on gen2 and on native, and is rejected
  on seed-min.
* Stdlib count: `tiny.sa` had 25 definitions, not the 30 the old row claimed.
  The current count is 36 (see the table).

### Pure-min measured divergences (probed 2026-10-10, one line per feature)

| Program | seed-min | gen2 | native |
|---|---|---|---|
| `show gc()` | rejected | `1` | `1` |
| `for v in xs` (list) | rejected | `1` `2` | rejected by name |
| `break` / `and` / generic `make id<T>` | rejected | works | `break` and generics rejected by name; `and` in a `when`/`while` condition works (added 2026-10-11, `test-native-cond`) |
| `hold` inside `make` | `3` | `3` | rejected (item 7, deferred) |
| `use "stdlib/tiny.sa"`, `isqrt(50)` | `7` | `7` | `7` |
| `use "stdlib/str_util.sa"`, `s_len("abc")` | rejected (typed params) | `3` | rejected (typed params) |
| `when s < "c"` on a string | `1` | `1` | `1` (byte order, added 2026-10-10, `test-native-strord`) |
| `push(xs, 4)` then `len(xs)` | `1` | `1` | `1` |
| struct `P { 3 }`, `p.x` | `3` | `3` | `3` |

The probe is a shell loop over the three binaries; it is not a gate. The gates
are the `test-*` targets named in the table.

