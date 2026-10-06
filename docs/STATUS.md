# Status

Last updated: 2026-10-06

## Entry

```bash
make doctor             # -> DOCTOR-OK                log: docs/logs/make-doctor.log
make true-selfhost      # -> TRUE-SELFHOST-MIN-OK     log: docs/logs/make-true-selfhost-min.log
make gen3               # -> GEN3-OK (gen3 == gen4)   log: docs/logs/make-gen3.log
make native-test        # -> NATIVE-TEST-OK           log: docs/logs/make-native-test.log
```

Today's raw output: `docs/logs/make-doctor.log`,
`docs/logs/make-true-selfhost-min.log`, `docs/logs/make-gen3.log`,
`docs/logs/make-native-test.log` (2026-10-06).

Everything below was verified by running those commands plus the per-feature
targets listed at the end of this file, on this host (3939 MB RAM, 2 CPUs,
`/bin/sh` = dash). Nothing in the table is aspirational. `docs/logs/` holds the
overwritten with today's runs (2026-10-06).

## Minimal tool set (2026-10-06)

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
| `grep` | asserting markers in *generated C* | **required** (proved: without it `true-selfhost` exits 2) |
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

Positive control for the three "required" assert tools: with a `PATH` containing
only `make cc gcc as ld sh grep cmp mkdir`, `make true-selfhost`, `make gen3` and
`make native-test` all exit 0. No `curl`/`wget` and no interpreter is ever
executed — the bootstrap is fully offline.

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

## Bootstrap memory (2026-10-06)

`selfhost/compiler_min.sa` is 200,228 bytes (196 KB). The compiler builds its
output in a `body` buffer that is flushed into `obody` as soon as it passes
~1 KB (the flush is skipped while a function body is being collected, and the
emitted text and its order are unchanged). A flat accumulator copied the whole
program on every append — O(n^2), ~2.5 GB allocated, and `Killed` on low-RAM
hosts. Measured now, from a clean tree:

| Step | Peak RSS (VmHWM) |
|------|------------------|
| `seed-min` compiling `compiler_min.sa` -> `gen1_min.c` | 1.5 MB |
| `gen1_min` compiling `compiler_min.sa` -> `gen2.c` | 29 MB |
| `gen2` compiling `compiler_min.sa` -> `gen3.c` | 75 MB |

`make true-selfhost` takes 11.9 s and `make gen3` 7.4 s on this host, and
`gen2` still produces byte-identical output under `ulimit -v 400000` (a 400 MB
address-space cap), so there is no realistic way to hit the OOM killer.

## Coverage (pure-min dialect)

| Feature | seed-min | gen2 (compiler_min) | native (native_aot) |
|---------|----------|---------------------|---------------------|
| `hold` / `show` (num, str) | yes | yes | yes |
| `when` / `while`, `== != < <= > >=` | yes | yes | yes |
| `otherwise` after `}` | yes | yes | yes |
| `else` alias after `}` (true *and* false branch) | yes | yes | yes (false branch fixed 2026-10-06) |
| `+ -` on numbers, string `+` (concat) | yes | yes | yes |
| `*` | yes | yes | yes |
| `/` | yes (10/4 = 2.5) | yes (2.5) | **integers only** (10/4 = 2) |
| `%` modulo | yes | yes | yes |
| chained ops (`a + b + c`; `* / %` bind tighter, left-assoc) | yes | yes | yes |
| `%` inside `when`/`while` conditions | yes | yes | yes |
| `make` / `give` (top level, numeric) | yes | yes | **no (clear error)** |
| recursion | yes | yes | **no (clear error)** |
| lists: `[..]`, `xs[i]`, `len` | yes | yes | yes |
| `hold xs = push(xs, v)` (expression form) | yes | yes | yes |
| bare `push(xs, v)` statement | **no** (`stmt at ...` error) | **no** (emits C that fails to compile) | yes |
| structs: number fields, `p.x`, `Point { 1, 2 }` | yes | yes | yes |
| structs: string fields (`name: "ada"`) | yes | yes | yes |
| structs: nested 2 and 3 deep (`Line { a: Point { 1, 2 } }`, `l.a.x`), typed copy `hold m = l.a` | yes | yes | yes (verified with `make native-test`) |
| copy of a doubly nested field (`hold p2 = r.q.p`) | **no** (error) | yes | yes |
| string builtins: `concat len chr` | yes | yes | yes |
| string builtins: `string_eq` | yes | yes | yes (numeric result) |
| string builtins: `sx_index read_file write_file arg arg_count` | yes | yes | **partial / not supported** (see divergences) |
| `use "file.sa"` (modules) | yes | yes | **no (clear error)** |
| base `OP` operand (`10 % 3`, `p.x + p.y`, `xs[1] + 5`, `len(xs) + 1`) | yes | yes | yes |
| parenthesized base expression (`(a + 3) * 4`) | yes (20) | **no** (clear error) | yes (20) |
| fractional literal (`hold x = 2.5`) | **no** (`id at ...` error) | **no** (prints 2) | **no** (`expected a field name after .`) |

## Measured divergences (2026-10-06)

Every row was run through all three backends on one file; "error" means the
compiler refused and said why, "C error" means it emitted C that does not
compile.

| Program | seed-min | gen2 | native |
|---------|----------|------|--------|
| `when 1 == 2 { show 11 } else { show 22 }` | `22` | `22` | `22` (was nothing before the 2026-10-06 fix) |
| `when 1 == 2 { show 11 } otherwise { show 22 }` | `22` | `22` | `22` (same fix) |
| `hold a = 10` / `show a / 4` | `2.5` | `2.5` | `2` (integer division) |
| `hold a = 2` / `show (a + 3) * 4` | `20` | error: `a parenthesized base is not supported...` + `#error` in the emitted C | `20` |
| `hold x = 2.5` / `show x` | error: `id at 11` | **prints `2`** (silently drops `.5`) | error: `expected a field name after .` |
| `hold xs = []` / `push(xs, 5)` (bare statement) | error: `stmt at 13` | **C error** (`'s' undeclared`) | `len`/index correct |
| `hold s = "abc"` / `show sx_index(s, 0)` | `97` | `97` | error: `string index out of range` |
| `show arg_count()` (no arguments) | `1` (argv[0]) | `1` | `0` |
| `show arg(0)` | path of the binary | path of the binary | **compiles, then segfaults** |
| `show read_file(p)` (existing file) | `hi` | `hi` | prints nothing (empty string) |
| `show write_file(p, s)` then `show read_file(p)` | `1` then `zz` | `1` then `zz` | `0` then nothing |
| bare `write_file(p, s)` statement | error: `stmt at 0` | C error | runs as a call, silently fails |
| 3-level chain copy `hold p2 = r.q.p` | error (misleading: `struct R field 'q' has no struct type`) | `7` | `7` |

The documented dialect (see `docs/SYNTAX.md`, `docs/CHEATSHEET.md`) shows
`push(xs, 4)` as a statement, which only native accepts. Use
`hold xs = push(xs, v)` — the expression form works on all three.

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
make native-test     # real x86-64: 42, -42, while/done, 10 % 3, else, slot/undefined, lists, structs
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
  value is a hard error in gen2. One asymmetry is left: copying a *doubly*
  nested field (`hold p2 = r.q.p`) is rejected by seed-min with a misleading
  message (`struct R field 'q' has no struct type`) while gen2 and native
  accept it — see the divergence table above. Copying one level
  (`hold m = l.a`) works everywhere.
* **A parenthesized base expression is not supported by gen2.** `show (a + 3)
  * 4` works in seed-min and native, but `compiler_min` reports
  `a parenthesized base is not supported by this compiler...` and emits a C
  `#error` plus a diagnostic line. Write the expression without outer
  parentheses (`hold t = a + 3` then `show t * 4`), or use seed-min/native for
  that source. This is a parser gap in the min dialect that the C seed does not
  share; it is documented rather than hidden, and `make test-prec` pins it.
* **Fractional literals are not part of pure-min.** `hold x = 2.5` is a clear
  error in seed-min and native; gen2 silently reads the integer part and prints
  `2`. Use integers, or compute `10 / 4` instead of writing `2.5`.
* **Lists** are `double`-only, one type per program; `push` returns the list.
* **Functions**: top level only, numeric params/return, recursion works.
  Calling a user function is supported in `hold` RHS, `show` and `give`.
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
* **native_aot** covers `hold/show/when/else/while`, integers, `+ - * / %`,
  comparisons, `show "str"`, string `concat`/`len`/`chr`/`string_eq`, literal
  lists (`[1, 2]`, `xs[i]`, `len`, `push` — the list grows in place,
  out-of-range indexes die), and structs including nested ones
  (`Line { a: Point { 1, 2 } }`, `l.a.x` chains, typed copies of a struct
  field). Every distinct variable name gets its own stack slot (two names
  sharing a first letter no longer share storage) and an undeclared name is a
  hard error instead of reading as 0. `make`/`give`/recursion, `use`, field
  access on a non-struct, a later-declared nested struct, a list inside a
  struct field and `show` of a struct value are rejected with a clear error.
  **Not supported, and not always loudly:** `/` is integer division, the file
  and argument builtins (`read_file`, `write_file`, `arg`, `arg_count`,
  `sx_index`) are compiled but do not work (see the divergence table), and a
  bare `push(xs, v)` statement is accepted although seed-min and gen2 reject
  the statement form. Native output is x86-64 Linux only.
  Functions (`make`/calls) and `use` are rejected with a clear error rather
  than emitting untested code; nested-struct field chains are WIP. The
  runtime is a flat BSS data area plus one `mmap` allocator with a linked
  free list (malloc/memcpy/copy semantics verified by probe programs).
* Still not part of pure-min: modules with namespacing/aliases, generics, a
  GC — none of these are claimed anywhere.

## Feature tests

| Target | Covers |
|--------|--------|
| `make test-reassign` / `test-while` / `test-when` | core statements |
| `make test-mod` | `%` lowering + `else` alias |
| `make test-chain` | chained `+ - * / %`, precedence, string `+` (seed-min and gen2 agree) |
| `make test-condmod` | `%` long-cast rewrite inside `when`/`while` conditions |
| `make test-struct2` | named fields, two structs, `p.x + p.y` |
| `make test-user` | struct string fields (`User name/age`); mismatches are hard errors |
| `make test-nest` | nested structs in seed-min and gen2 (output parity, 3-level deep, ordered struct-typed fields, typed copies); clear errors for forward decls, list fields, bad chains, show-of-struct |
| `make test-list2` | literal, index, `len`, `push` |
| `make test-use` | splice, nested depth 2, missing-file error |
| `make test-fn2` | params, call in `show`, recursion (`fac 5 = 120`) |
| `make test-boot` | gen2 compiles `compiler_boot.sa` and the result runs |
| `make test-parity` | seed-min and gen2 agree on one program using the whole shared dialect |
| `make seed-min` / `test-struct` / `test-list` / `test-fn` | same features on the C seed |
| `make test-prec` | precedence (`a + 3 * 4` = 14 in seed-min and gen2) and the parenthesized-base divergence (seed-min runs it, gen2 reports it) |
| `make native-test` | native subset, one slot per name, undefined names, list ops + push/grow + bounds, structs, nested structs (2 and 3 levels, typed copy, seed-min/gen2 output parity), `else`/`otherwise` false branch, unsupported constructs rejected |
