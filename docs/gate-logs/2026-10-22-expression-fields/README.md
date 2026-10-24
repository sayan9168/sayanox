# Expression fields and checked index calls (2026-10-22)

| Claim | Where it is checked |
|---|---|
| A struct literal field may be a whole checked expression: `Size { bytes: len(text) + 1 }`, `(2 + 3) * 4`, `offset() + twice(3)`, `head + "anox"` | `make test-full-language-expr` |
| An index may call a function the program declared with `-> num`: `values[offset()]`, `values[twice(offset()) + 1]`, `values[twice(offset()) % 3]` | `make test-full-language-expr` |
| Both forms print the same eleven lines on seed-min, gen2 and native | `make test-full-language-expr` (`cmp`) |
| The four broader-language readiness probes pass on gen2 **and** gen3 — 8/8 | `make test-full-language-readiness`, now invoked by `make gen3` |
| Passing them is still **not** a full-language claim | the same gate greps `true-selfhost-full` for its refusal and its `exit 1` |

This closes the last two rows of the readiness table in
`docs/FULL_LANGUAGE_SELFHOST.md`. It does **not** close row 1 of the status
matrix: the claim needs a reviewed acceptance specification, plus seed/native
interpolation and struct function signatures, none of which exist.

## This was gen2-only work

seed-min and native already compiled both forms. Running the two probe files
through all three backends before touching anything:

```
selfhost/full_language_tests/field_expression.sa   seed-min 4   native 4   gen2 #error
selfhost/full_language_tests/index_call.sa         seed-min 9   native 9   gen2 #error
```

So this is a parity fix, and the fixture `selfhost/full_language_expr.sa` is
a three-way `cmp`, not a new language feature invented for gen2.

## What actually blocked it

**1. The struct-literal walker had four value shapes.** A value could be a
number, a quoted string, a name, or a nested literal; anything else fell
through to the progress guard and became `struct/list literal value must be a
number, string, name, or nested struct`. The walker *already* called the
checked expression parser `sxeparse` at that position — but used the result
only when the value turned out to be a **list** (the concrete list-field
work from 2026-10-14).

The fix widens the pre-parse to values starting with a digit, `(`, `-` or `"`
as well, and then takes the parser's result only when

* the parser consumed **more** than the simple form would have, **and**
* the extra text starts with an operator (`+ - * / %`) or a call's `(`.

That second condition is what keeps the existing refusals exactly where they
were: `.` and `[` are deliberately not in the set, so `NumBox { a.v }` (a
dotted field read inside a literal, pinned by `test-generic-structs`) and
`Size { bytes: xs[0] }` still refuse on gen2. The field takes the
expression's kind, so `head + "anox"` makes a `char *` field.

**2. A grouping `(` hijacked the whole statement.** `hold a = Size { bytes:
(2 + 3) * 4 }` was routed into the parenthesised-expression rewrite, which
has never accepted a `{`, so the diagnostic was the confusing `unexpected '{'
in a parenthesized expression`. The statement scanner now tracks brace depth
and only treats a grouping `(` as statement-level when it is outside every
struct literal.

**3. `idx_lower` lowered exactly one call.** It special-cased `len(NAME)` and
refused every other `(`. It now also accepts a call to a function the program
declared with `-> num`: it finds the matching `)` (counting nested `(` and
`[`), splits the arguments at top-level commas, lowers each one as its own
index expression, and checks the arity and that every declared parameter is a
number. The function tables (`fsret`, `fspk`) are new parameters, so they
travel with the recursion and nested calls such as `twice(offset())` work.

## The fixture

`selfhost/full_language_expr.sa`, eleven lines, byte-identical on seed-min,
gen2 and native:

```
4         Size { bytes: len(text) + 1 }
20        Size { bytes: (2 + 3) * 4 }
2         Size { bytes: len("hello") % 3 }
4         Size { bytes: span / 2 - 1 }
7         Size { bytes: offset() + twice(3) }
sayanox   Label { text: head + "anox" }     -- a string expression, a str field
9         values[offset()]
11        values[twice(offset())]
13        values[twice(offset()) + 1]
11        values[len(pair)]
11        values[twice(offset()) % 3]
```

The gate also pins gen2's lowered C, because the lowering *is* the claim:

```
Size one = ((Size){(sx_len(text) + 1.0)});
Size two = ((Size){(((2.0 + 3.0)) * 4.0)});
Size five = ((Size){(offset() + twice(3.0))});
Label tag = ((Label){sx_cat(head,"anox")});
sx_lget(values,twice(offset()))
```

## What stays refused

| Form | seed-min | gen2 | native |
|---|---|---|---|
| `values[nope()]` (unknown function) | refuses | `#error` | refuses |
| `values[two(1)]` (wrong arity) | refuses | `#error` | refuses |
| `values[tag()]` where `tag` is `-> str` | accepts; its C does not compile | `#error` | refuses |
| `values[pick(xs)]` (a `list` parameter) | accepts | `#error` | accepts |
| `values[len("ab")]` (a quote in an index) | accepts | `#error` | accepts |
| `Label { text: concat(a, b) }` (source-level builtin call) | accepts | `#error` | accepts |
| `NumBox { a.v }` (dotted field read in a literal) | accepts | `#error` | refuses |

The first three rows are asserted by the new gate. The last four are
**older divergences this pass did not change** — gen2 is the strict one, and
`test-gen2-index-expr` / `test-generic-structs` have pinned them for weeks.
The workaround in every case is a `hold` first.

The builtin-call row has a specific cause worth recording: the checked parser
knows the C runtime names (`sx_cat`, `sx_chr`, ...) and only two source
aliases, `len` and `index`. Teaching it the rest would widen every caller of
`sxeparse` at once, so it was left alone and documented instead.

## Why `make gen3` now runs the readiness probes

`test-full-language-readiness` was only reachable through
`true-selfhost-full`, which fails closed on purpose — so nothing in the four
hard gates ever ran it, and "four unmet checks" was a number in a document
rather than a gate. gen3 exists by the end of the `gen3` target, so the probes
now run there. A regression in any of the four behaviours breaks a hard gate.

## The bootstrap caught a scoping bug the dev loop could not

The first hard-gate run failed at step 2 with

```
selfhost/gen2.c:7826:29: error: 'flrun' undeclared (first use in this function)
selfhost/gen2.c:7831:33: error: 'flc' undeclared (first use in this function)
```

The new value scanner used `hold flrun` / `hold flc` in three sibling `when`
blocks. seed-min hoists a function's locals, so `gen1_min.c` compiled and
every fixture passed; gen1_min scopes a `hold` to its block, so the *second*
sibling emitted an assignment with no declaration and `gen2.c` would not
compile. This is the hazard already written down at `docs/STATUS.md` line
~2215 and in `docs/FULL_LANGUAGE_SELFHOST.md`; it is invisible until a
generation compiles the compiler.

Fixed by giving each sibling block its own names (`flruna/flca`,
`flrunb/flcb/flcb2`, `flrunc/flcc`, `flrund/flcd`) and a comment above the
block saying why. Behaviour is unchanged: the fixture still prints the same
eleven lines on all three backends.

## Gates

```
make test-full-language-expr        # the new three-backend fixture + refusals
make test-full-language-readiness   # 8/8, now also run by `make gen3`
make test-gen2-index-expr           # the index refusals that must survive
make test-gen2-expr-lowering
make test-generic-structs           # NumBox { a.v } stays refused on gen2
make test-struct2 test-nest test-struct-functions test-list-struct-fields
make test-gen2-list-struct-fields test-type-refusals test-doc-claims
make test-language-deps
```

and the four hard gates:

```
make doctor         # DOCTOR-OK
make true-selfhost  # TRUE-SELFHOST-MIN-OK (test-full-language-expr runs inside)
make gen3           # GEN3-OK (gen3 == gen4, readiness 8/8)
make native-test    # NATIVE-TEST-OK
```

See `hard-gates.log` for the markers and the line numbers at which this
increment's gates ran inside the aggregates.
