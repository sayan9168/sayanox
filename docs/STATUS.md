# Status

Last updated: 2026-10-03

## Entry

```bash
make true-selfhost      # -> TRUE-SELFHOST-MIN-OK
make gen3               # -> GEN3-OK (gen3 == gen4 byte-identical)
```

Everything below was verified by running those commands plus the per-feature
targets listed at the end of this file. Nothing in the table is aspirational.

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
| `make` / `give` (top level, numeric) | yes | yes | **no (clear error)** |
| recursion | yes | yes | **no (clear error)** |
| lists: `[..]`, `xs[i]`, `len`, `push` | yes | yes | **no (clear error)** |
| structs: numeric fields, `p.x`, `Point { x: 3 }` | yes | yes | **no (clear error)** |
| string builtins (`concat len chr sx_index read_file write_file arg arg_count string_eq`) | yes | yes | `show "str"` only |
| `use "file.sa"` (modules) | yes | yes | **no (clear error)** |
| base `OP` operand (`10 % 3`, `p.x + p.y`, `xs[1] + 5`, `len(xs) + 1`) | yes | yes | yes |
| chained ops (`a + b + c`) | yes | no (first op only) | yes |
| `%`/`*`/`/` inside `when`/`while` conditions | yes | no (copied verbatim) | yes |

`%` lowers to `(double)((long)(a)%(long)(b))` on seed-min and gen2, and to a
real `idiv`/remainder in the native backend, so all three agree on
`10 % 3 == 1`.

## Verified behaviour

```bash
make true-selfhost   # seed-min -> gen1_min -> gen2, then gen2 feature tests
make gen3            # gen3 == gen4 spec check + feature tests on gen3
make native-test     # real x86-64: 42, -42, while/done, 10 % 3, else, rejections
make seed-min        # seed-min: hold/show/while/struct/list/fn/%/else/use
```

Program:

```sayanox
hold a = 10
show a % 3
when a > 5 { show 1 } else { show 0 }
```

prints `1` then `1` via gen2 (and via seed-min and via native).

## Honest boundaries

* **Modules** (`use "file.sa"`): spliced before parsing, depth <= 8, only at a
  real statement start (never inside strings or `//` comments). A missing file
  is a hard error: gen2 emits `#error` into the generated C (so the C compile
  fails loudly); seed-min prints to stderr and exits non-zero. An unquoted
  path (`use other.sa`) is reported the same way instead of being compiled as
  garbage identifiers. Paths resolve against the current directory first, then
  next to the input file.
* **Structs** are **numeric fields only** — one `double` per field. A string
  value in a struct or list literal is reported as an error, not silently
  mis-compiled. Nested struct values are not supported.
* **Lists** are `double`-only, one type per program; `push` returns the list.
* **Functions**: top level only, numeric params/return, recursion works.
  Calling a user function is supported in `hold` RHS, `show` and `give`.
* **Statements are newline-terminated**: write one statement per line. In
  particular `give 0 }` on one line swallows the `}` into the returned
  expression; the compiler now reports that as an error instead of letting it
  become invalid C.
* **`hold`/`show`** accept one binary operand after any base — number, name,
  field (`p.x + p.y`), index (`xs[1] + 5`) or call (`len(xs) + 1`) — a chain
  such as `a + b + c` still uses the first operator only.
* **`use` paths** resolve against the current directory first, then next to
  the input file, so `./selfhost/gen2 dir/main.sa out.c` finds `dir/lib.sa`.
* **Conditions** in `when`/`while` are copied verbatim as C text; operators
  there must be valid C (`%` is *not* rewritten to the long-cast form there).
* **native_aot** covers `hold/show/when/else/while`, integers, `+ - * / %`,
  comparisons and `show "str"`. Lists, structs, functions, `use` and index
  expressions are rejected with an `unsupported:` message instead of emitting
  wrong code.
* Still not part of pure-min: modules with namespacing/aliases, string fields,
  nested structs, generics, a GC — none of these are claimed anywhere.

## Feature tests

| Target | Covers |
|--------|--------|
| `make test-reassign` / `test-while` / `test-when` | core statements |
| `make test-mod` | `%` lowering + `else` alias |
| `make test-struct2` | named fields, two structs, `p.x + p.y` |
| `make test-list2` | literal, index, `len`, `push` |
| `make test-use` | splice, nested depth 2, missing-file error |
| `make test-fn2` | params, call in `show`, recursion (`fac 5 = 120`) |
| `make test-parity` | seed-min and gen2 agree on one program using the whole shared dialect |
| `make seed-min` / `test-struct` / `test-list` / `test-fn` | same features on the C seed |
| `make native-test` | native subset + unsupported-construct rejection |
