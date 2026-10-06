# Status

Last updated: 2026-10-04

## Entry

```bash
make true-selfhost      # -> TRUE-SELFHOST-MIN-OK      log: docs/logs/make-true-selfhost-min.log
make gen3               # -> GEN3-OK (gen3 == gen4)    log: docs/logs/make-gen3.log
make native-test        # -> NATIVE-TEST-OK            log: docs/logs/make-native-test.log
```

Everything below was verified by running those commands plus the per-feature
targets listed at the end of this file. Nothing in the table is aspirational.
`docs/logs/` holds the raw output of those three runs (2026-10-04).

```bash
make doctor             # -> DOCTOR-OK, checks the tool set below
```

## Minimal tool set (2026-10-04)

Full audit, measurements and method: **[`DEPENDENCY.md`](../DEPENDENCY.md)**.

The bootstrap needs a host C toolchain and `make` — that is not "zero
dependencies" and is not claimed to be. What it does *not* need is any
interpreted language: no Python, Node or Ruby process is ever started on any
target, and no such file is tracked in the repository.

| Tool | Needed for | Status |
|------|-----------|--------|
| `make` | the only entry point | **required** |
| C99 compiler (`cc`/`clang`/`gcc`) | building seed-min, gen1_min, gen2, gen3, native_aot | **required** |
| POSIX shell | recipe lines (verified under dash) | **required** |
| `grep` | asserting markers in *generated C* | **required** |
| `cmp` | `gen3 == gen4` fixed point, seed-min/gen2 parity | **required** |
| `mkdir` | scratch test directory | **required** |
| `base64`, `gzip` | **only** the offline `compiler_min.sa` fallback | optional |

Measured external commands per target (`as`/`ld` are internal to the compiler):

| Target | External commands |
|--------|-------------------|
| `make true-selfhost` | `cc cmp grep make mkdir` |
| `make gen3` | `cc cmp make mkdir` |
| `make native-test` | `cc grep make mkdir` |

Removed from the critical path in this pass: `sed`, `awk`, `diff`, `wc`, `cat`,
`tr`, `base64`, `gzip`. No `curl`/`wget` — the bootstrap is fully offline.

`fix-seed` was ~20 lines of `awk` + `sed -i` rewriting the seed sources in
place. Every edit in it was dead: the `awk` guard's grep pattern
`ptok(k,(const char*)#ch` is a BRE where `r*` means "zero or more `r`", so it
could never match, and all six `sed -i` guards looked for pre-fix text that is
no longer in the checked-in sources. It is now `verify-seed`, a read-only
assertion (`fix-seed` remains as an alias). Test assertions moved off
`sed -n Np` onto a pure-shell `assert-out` helper that compares whole stdout
using only builtins, which is stricter than the per-line checks it replaced.

## Bootstrap memory (2026-10-04)

The geometric-grow string builder was rewritten to a simpler "always-fresh
allocation, evaluate RHS to a temp first before freeing the LHS" model.
Complier_min.sa (137 KB) now compiles in ~7 seconds peak RSS ~120 MB with
**~21 MB total allocated** across the whole run (down from the 1.7 GB of the
prior never-free baseline; from the OOM Killed result that motivated this
fix). There are no reference counts and no manual drops in the emitted code —
ownership is local to each assignment.

## Coverage (pure-min dialect)

| Feature | seed-min | gen2 (compiler_min) | native (native_aot) |
|---------|----------|---------------------|---------------------|
| `hold` / `show` (num, str) | yes | yes | yes |
| `when` / `while`, `== != < <= > >=` | yes | yes | yes |
| `otherwise` after `}` | yes | yes | yes |
| `else` alias after `}` | yes | yes | yes |
| `+ -` on numbers, string `+` (concat) | yes | yes | `+ -` numbers |
| `*` `/` | yes | yes | yes |
| `%` modulo | yes | yes | yes |
| chained ops (`a + b + c`; `* / %` bind tighter, left-assoc) | yes | yes | yes |
| `%` inside `when`/`while` conditions | yes | yes | yes |
| `make` / `give` (top level, numeric) | yes | yes | **no (clear error)** |
| recursion | yes | yes | **no (clear error)** |
| lists: `[..]`, `xs[i]`, `len`, `push` (grows in place) | yes | yes | yes |
| structs: number fields, `p.x`, `Point { 1, 2 }` | yes | yes | yes |
| structs: nested (`Line { a: Point { 1, 2 } }`, `l.a.x`) | yes | yes | **WIP** (literals OK, chained fields broken) |
| string builtins (`concat len chr sx_index read_file write_file arg arg_count string_eq`) | yes | yes | `show "str"` only |
| `use "file.sa"` (modules) | yes | yes | **no (clear error)** |
| base `OP` operand (`10 % 3`, `p.x + p.y`, `xs[1] + 5`, `len(xs) + 1`) | yes | yes | yes |

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
  work in **both seed-min and gen2** (verified with output parity in
  `make test-nest`, including three levels deep). Rules, enforced by both:
  the nested struct must be declared before the struct that nests it (so
  typedefs stay dependency-ordered), a struct-valued field must be filled in
  every literal, a struct value can be copied with a typed declaration
  (`hold m = l.b`, `hold r = q`), and a chain through a field that has no
  struct type is a hard error. A list inside a struct field and a struct
  value inside a list are hard errors in both compilers; `show` of a struct
  value is a hard error in gen2.
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
  comparisons, `show "str"`, literal lists (`[1, 2]`, `xs[i]`, `len`,
  `push` — the list grows in place, out-of-range indexes die), and structs
  (number fields, `Point { 1, 2 }`, `p.x`). Every distinct variable name gets
  its own stack slot (two names sharing a first letter no longer share
  storage) and an undeclared name is a hard error instead of reading as 0.
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
| `make native-test` | native subset, one slot per name, undefined names, list ops + push/grow + bounds, structs, unsupported constructs rejected |
