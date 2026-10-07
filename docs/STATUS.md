# Status

Last updated: 2026-10-07

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
they were last regenerated 2026-10-07.

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

Positive control for the three "required" assert tools, re-run 2026-10-07 on a
fresh `git clone` with a `PATH` containing only `make cc gcc as ld sh grep cmp
mkdir`: `make doctor`, `make true-selfhost`, `make gen3` and `make native-test`
all exit 0 with no `not found` line, and the clone has no untracked files
afterwards. No `curl`/`wget` and no interpreter is ever executed — the
bootstrap is fully offline. `make native-test` additionally needs an **x86-64
Linux** host, because `native_aot` writes x86-64 Linux ELF executables;
`true-selfhost` and `gen3` emit portable C.

Removed from the critical path in the earlier pass: `sed`, `awk`, `diff`, `wc`,
`cat`, `tr`, `base64`, `gzip` (the last five survive only in the optional
offline-restore fallback). `selfhost/pack_compiler_min.sh` still uses
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

## Bootstrap memory (re-measured 2026-10-07)

`selfhost/compiler_min.sa` is 239,782 bytes (234 KB; it was 200,228 bytes on
2026-10-06 — the growth is the new features and error checks below). The compiler builds its
output in a `body` buffer that is flushed into `obody` as soon as it passes
~1 KB (the flush is skipped while a function body is being collected, and the
emitted text and its order are unchanged). A flat accumulator copied the whole
program on every append — O(n^2), ~2.5 GB allocated, and `Killed` on low-RAM
hosts. Measured 2026-10-07 (peak RSS from `wait4` `ru_maxrss`):

| Step | Peak RSS | (2026-10-06) |
|------|----------|--------------|
| `seed-min` compiling `compiler_min.sa` -> `gen1_min.c` | 1.8 MB | 1.5 MB |
| `gen1_min` compiling `compiler_min.sa` -> `gen2.c` | 39.5 MB | 29 MB |
| `gen2` compiling `compiler_min.sa` -> `gen3.c` | 99.2 MB | 75 MB |

From a fresh clone, `make true-selfhost` takes ~19 s, `make gen3` ~11 s and
`make native-test` ~2 s on this host (more tests than on 2026-10-06), and `gen2` still produces
byte-identical output under `ulimit -v 400000` (a 400 MB address-space cap,
re-checked 2026-10-07), so there is no realistic way to hit the OOM killer.

## Coverage (pure-min dialect)

| Feature | seed-min | gen2 (compiler_min) | native (native_aot) |
|---------|----------|---------------------|---------------------|
| `hold` / `show` (num, str) | yes | yes | yes |
| `when` / `while`, `== != < <= > >=` | yes | yes | yes |
| `otherwise` after `}` | yes | yes | yes |
| `else` alias after `}` (true *and* false branch) | yes | yes | yes (false branch fixed 2026-10-06) |
| `+ -` on numbers, string `+` (concat) | yes | yes | yes |
| string `+` number (`"a" + 1`) | error | error (was silently wrong: `s + n` printed the *name* `n`) | yes, `a1` (extension; was `11` before 2026-10-07) |
| `*` | yes | yes | yes |
| `/` | yes (10/4 = 2.5) | yes (2.5) | yes (2.5; IEEE double, 2026-10-07) |
| `/` by zero | `inf` / `-nan` | `inf` / `-nan` | `inf` / `-nan` |
| `%` modulo (truncates both sides, `-7 % 3` = -1) | yes | yes | yes |
| `%` by zero | crash: SIGFPE (exit 136) | crash: SIGFPE (exit 136) | exit 1, `division by zero` |
| chained ops (`a + b + c`; `* / %` bind tighter, left-assoc) | yes | yes | yes |
| `%` inside `when`/`while` conditions | yes | yes | yes |
| `make` / `give` (top level, numeric) | yes | yes | yes (enabled 2026-10-06; `hold` inside a body is a clear error) |
| recursion | yes | yes | yes (`fac(5)` = 120, `fib(20)` = 6765, mutual recursion) |
| lists: `[..]`, `xs[i]`, `len` | yes | yes | yes |
| `hold xs = push(xs, v)` (expression form) | yes | yes | yes |
| bare `push(xs, v)` statement | yes (2026-10-07) | yes (2026-10-07) | yes |
| bare call statement (`write_file(p, s)` on its own line) | error: `unknown statement` | error: `unknown statement` | yes (runs the call) |
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
| list literal with 10+ elements | yes | yes (was invalid C) | yes |
| whole-list copy `hold ys = xs` | yes | yes (2026-10-07) | yes |

## Measured divergences (2026-10-07)

Every row was run through all three backends on one file on 2026-10-07.
"error" means the compiler refused and said why. Rows that agreed on all three
have been dropped: `10 / 4`, `2.5`, `(a + 3) * 4`, bare `push`, `arg_count()`,
`arg(0)`, `read_file`, `write_file`, `else`/`otherwise`, `sx_index` and
`hold p2 = r.q.p` now give identical output everywhere (see the coverage
table), and 64 of the repository's `.sa` programs produce byte-identical output
on seed-min, gen2 and native.

| Program | seed-min | gen2 | native |
|---------|----------|------|--------|
| bare `write_file("o.txt", "zz")` statement | error: `unknown statement 'write_file'` | error: `unknown statement 'write_file'` | runs the call (then `read_file` gives `zz`) |
| `hold s = "a"` / `show s + 1` | error: `+ joins two strings or adds two numbers ...` | error: `+ joins two strings; '1' is not a string ...` | `a1` |
| `show 7 % 0` | killed by SIGFPE (exit 136) | killed by SIGFPE (exit 136) | exit 1, `division by zero` |
| `show 100000 * 100000` | **`1.41007e+09`** | **`1.41007e+09`** | `1e+10` |

The last row is the only *silent* divergence left, and it is pre-existing:
seed-min and gen2 copy integer literals into the C output verbatim, so a
`+ - *` (sub-)expression whose operands are *only* integer literals is folded
by the C compiler in 32-bit `int` and can overflow past 2^31 — also inside a
larger expression (`a + 100000 * 100000`). An operation with a variable or a
fractional-literal operand, and every `/`, is computed in `double` and agrees
on all three (`hold a = 100000` / `show a * 100000` and
`show 100000 * 100000.0` print `1e+10` everywhere). Fixing it
means emitting every literal as a C double (`100000.0`) in seed-min and in
gen2's seven literal readers plus its verbatim condition rewrite; that was not
done in this pass. Until then, keep large constants in variables.

The documented dialect (see `docs/SYNTAX.md`, `docs/CHEATSHEET.md`) shows
`push(xs, 4)` as a statement; since 2026-10-07 all three backends accept it,
and `hold xs = push(xs, v)` keeps working everywhere.

`%` lowers to `(double)((long)(a)%(long)(b))` on seed-min and gen2 — including
inside `when`/`while` conditions — and to a real `idiv`/remainder in the native
backend, so all three agree on `10 % 3 == 1`.

Struct field types come from the literals that fill them: a field is `double`
or `char *`, the first literal that mentions it decides, and a conflicting
later literal is a hard error. `hold s = u.name` is typed as a string.

## Verified behaviour

```bash
make true-selfhost   # seed-min -> gen1_min -> gen2, then every feature test on gen2
make gen3            # gen3 == gen4 byte-identical + feature tests on gen3
make native-test     # real x86-64: 42, -42, while/done, 10 % 3, else, slot/undefined,
                     # lists, structs, nested structs, use splice, functions/recursion,
                     # doubles (2.5, 10 / 4, %g output), file and argv builtins
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
* **Numbers are IEEE doubles** in all three backends: fractional literals
  (`2.5`, `0.75`; `2.` and `1.2.3` are clear errors), `/` is true division
  (`10 / 4` = 2.5, `1 / 0` = `inf`), `%` truncates both operands to integers
  first, and `show` prints like C's `printf("%g")` (`0.333333`, `1e+10`). See
  the divergence table for the integer-literal overflow caveat in seed-min and
  gen2, and for `%` by zero.
* **Strings and numbers do not mix in pure-min**: `+` joins two strings or adds
  two numbers. seed-min and gen2 reject `"a" + 1`, `1 + "a"` and `-`/`*`/`/`/`%`
  on strings with a clear error (gen2 used to paste the variable's *name* into
  the string: `s + n` printed `an`). native accepts string + number and
  formats the number with `%g` — an extension, not part of the shared dialect;
  use `concat(s, n)` if a program has to run everywhere.
* **Statements**: a statement starts with `hold show when while make give
  struct use` (plus `otherwise`/`else` after a `}`) or is a bare
  `push(xs, v)`. Anything else — `continue`, `gc`, a
  misspelled keyword, a bare `write_file(...)` call — is an `unknown
  statement` error in seed-min and gen2 (gen2 used to drop such lines silently
  or emit invalid C). native still runs a bare builtin call statement.
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
  "!"` concatenates strings, and `%` lowers to the long-cast form.
* **`use` paths** resolve against the current directory first, then next to
  the input file, so `./selfhost/gen2 dir/main.sa out.c` finds `dir/lib.sa`.
* **Conditions** in `when`/`while` are copied as C text with one rewrite: `%`
  becomes `(double)((long)(a)%(long)(b))`, so `while a % 10 > 0` is correct;
  the remaining operators must be valid C (`*`, `/` and comparisons are).
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
  a 160 KiB round trip). Differences from seed-min/gen2, all listed in the
  divergence table: native accepts string + number and a bare builtin call
  statement, and exits with `division by zero` on `% 0` where the C backends
  die of SIGFPE. Native output is x86-64 Linux only. The runtime is a flat
  BSS data area plus one bump allocator over lazily `mmap`ped 64 KiB chunks
  (malloc/memcpy/copy semantics verified by probe programs).
* **Known gen2 gaps outside pure-min**: three Stage-2 demo programs in the
  repository are not in the min dialect and gen2 fails on them loudly:
  `selfhost/minimal_lexer.sa` (link error), `selfhost/stage2_functions.sa`
  (C error: `'result' undeclared`) and `selfhost/stage2_variables.sa`
  (`#error`). None of them is used by any bootstrap target.
* Still not part of pure-min: modules with namespacing/aliases, generics, a
  GC — none of these are claimed anywhere (see "Out of scope" below).

## Feature tests

| Target | Covers |
|--------|--------|
| `make test-reassign` / `test-while` / `test-when` | core statements |
| `make test-mod` | `%` lowering + `else` alias |
| `make test-chain` | chained `+ - * / %`, precedence, string `+` (seed-min and gen2 agree) |
| `make test-condmod` | `%` long-cast rewrite inside `when`/`while` conditions |
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
| `make test-float` | fractional literals and true division in seed-min and gen2 (`2.5`, `10 / 4` = 2.5, `1 / 3` = 0.333333, negative fractions); `2.` and `1.2.3` are errors, but not inside strings or comments |
| `make test-parens` | parenthesized expressions in seed-min and gen2 (`(a + 3) * 4` = 20, nesting, unary minus, parens in conditions and `give`); non-numeric and unbalanced parens are clear errors |
| `make test-push-stmt` | bare `push(xs, v)` in seed-min and gen2; push onto a non-list, unknown statements, string + number, number + string, string `-` and `*`, a string list element, 10+ element list literals, struct-in-list, `hold ys = xs`, list arithmetic — all clear errors or correct output |
| `make test-native-num` (part of `native-test`) | native doubles: `test-float`/`test-parens`/`test-push-stmt` programs give the same output as seed-min and gen2; `%` truncation, `%g` formatting, `1 / 0` = `inf` (same as seed-min), `% 0` dies, string + number, struct-field string chains |
| `make test-native-io` (part of `native-test`) | native `read_file`/`write_file`/`arg`/`arg_count` give the same results as seed-min and gen2 (argv[0] counted, truncating write returns 1, missing file reads as `""`, 160 KiB round trip) |
| `make native-test` | native subset, one slot per name, undefined names, list ops + push/grow + bounds, structs, nested structs (2 and 3 levels, typed copy incl. doubly nested, seed-min/gen2 output parity), `use` splice (depth 2, input-dir resolution, missing-file and unquoted-path errors), functions (recursion `fac`/`fib`, 6 params, forward refs, mutual recursion, zero-arg, global assignment, builtin and string args), postfix right of `* / %` + left-assoc, string `s[i]`/`sx_index`, `else`/`otherwise` false branch, unsupported constructs rejected (incl. hold-inside-make, give-outside, make-in-block, wrong arg count/type, non-numeric give) |

## Out of scope

Not worked on in this pass and not claimed anywhere in this repository:

* the full Stage-2 language (everything beyond the pure-min dialect above)
* a garbage collector or any heap redesign (programs compiled by gen2 and
  native never free their strings and lists; seed-min's runtime frees only
  the previous value of a reassigned string variable)
* a package registry or versioned modules (`use "file.sa"` is a textual
  splice; `tools/sxpkg.sh` is an optional, unused script)
* an LSP server or IDE integration
* a full standard library (only the builtins in the coverage table exist)
* generics or a richer type system (values are doubles, strings, double lists
  and literal-typed structs)
