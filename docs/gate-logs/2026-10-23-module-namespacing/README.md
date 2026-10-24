# Module namespacing, as a pass written in Sayanox (2026-10-23)

`docs/MODULES.md` has said since 2026-10-16 that the bootstrap dialect has
textual `use` splicing and **no** module identity — one flat name table, no
aliases, no qualified names — and it warned in as many words: *"Unsupported —
do not emulate with path rewriting."* `docs/STATUS.md` row 10 said
**not planned**.

That is still true of the compiler. What changed today is that the capability
exists one layer out, as a program with its own gate:
`tools/sxmod.sa`, written in Sayanox, compiled by gen2.

| Claim | Where it is checked |
|---|---|
| The flat dialect **cannot** compose two modules that both declare `add` | `make test-sxmod` — seed-min *duplicate function name*, `cc` rejects the C gen2 emits, native_aot *declared twice*. All three asserted before anything else runs |
| The same two modules compose through the pass and print the same nine pinned lines under seed-min, gen2 and native_aot | `make test-sxmod` (`cmp` against the tracked `app.want`, then per backend) |
| The rewrite is deterministic | `make test-sxmod` (two runs, `cmp`) |
| It prefixes module-level names and their internal references, and touches nothing else — locals, parameters, struct fields, comments and string literals survive byte for byte | `make test-sxmod` (nine `grep` assertions, plus a negative one for `text__mark`, `math__once`, `math__v`, `p__x`) |
| A member is **not** visible unqualified | `make test-sxmod` — after the pass `add(2, 3)` names nothing and seed-min says *unknown function* |
| 16 refusals, each with a diagnostic and a non-zero exit | `make test-sxmod` (and the count itself is pinned, so adding a probe without documenting it fails) |

## The shape of the thing

```sayanox
module math from "selfhost/sxmod_tests/math.sa"
module text as t from "selfhost/sxmod_tests/text.sa"

show math.add(2, 3)      // 5
show t.add("a", "b")     // ab
show math.scale          // 10 -- a module-level `hold`
```

becomes plain bootstrap Sayanox:

```sayanox
hold math__scale = 10
make math__add(a: num, b: num) -> num { give a + b }
hold math__base = math__add(40, 2)
make text__add(a: str, b: str) -> str { give concat(a, b) }
show math__add(2, 3)
show text__add("a", "b")
show math__scale
```

Nine lines of output, identical on all three backends:
`5 / ab / 40 / 60 / 42 / hi! / add is a word in this string / 7 / 8`.

## Why the negative control comes first

A renaming pass that nobody needed would be a dressed-up `sed`. So the gate's
first three assertions are that the problem is real: `collide_flat.sa` splices
the *same two fixtures* with `use`, and

```
seed-min    : seed-min duplicate function name
cc on gen2.c: error: conflicting types for 'add'
native_aot  : function 'add' declared twice
```

Only then does it show the composed program working. If someone ever gives
the compiler a real module scope, the first half of this gate starts failing,
and that is the correct signal.

## The soundness rule that costs something

A textual rewrite has to know what a bare name means. If a module declares
`hold total` and one of its functions takes a parameter named `total`, the
pass cannot decide which one a bare `total` is — so it **refuses the module**
and names the line:

```
sxmod: …/shadow_p.sa line 2: the parameter 'total' shadows a top-level name
       of the same module; rename the parameter
```

The same applies to a local `hold` or a `for` name. That restriction is the
price of doing namespacing in a pass instead of in the compiler, and it is
written down in `docs/MODULES.md` rather than discovered later.

Dotted expressions are the other half of the rule: `alias.member` is rewritten
only when `alias` came from a `module` line, so `point.x` on a struct is
untouched. The gate pins `show p.x` surviving verbatim.

## The 16 refusals

unknown member · bare alias used as a value · duplicate alias · a module
declaring the same name twice · unreadable path · unquoted path · missing
`from` · a `module` line after the first statement · an uppercase module name
(it could collide with the compiler's `Struct__tag` generic specialisations) ·
a module that exports nothing · a program with no `module` line · `use` inside
a namespaced program · `use` inside a module file · a `module` line inside a
module file · a parameter shadowing a module name · a local shadowing a
module name.

## The four markers

```
DOCTOR-OK
TRUE-SELFHOST-MIN-OK
gen3 == gen4 (byte-identical)
NATIVE-TEST-OK
```

`hard-gates.log` in this folder has the run with timestamps.
`selfhost/compiler_min.sa` is untouched by this increment: the compiler did
not change, which is the whole claim.

## Increment gates on this tree

| Gate | Makefile line | What it adds |
|---|---|---|
| `test-sxmod` | 2299 (`.PHONY` 2298, `native-test:` 2382, aggregate line 43) | the whole claim above, five `[OK]` lines |
| `tools/sxmod` rule | 2100 | gen2 → C → reject `#error` → `cc` |

Fixtures: `selfhost/sxmod_tests/{math,text}.sa` (two modules that both declare
`add`), `app.sa` (the program), `app.want` (the pinned nine lines),
`collide_flat.sa` (the negative control), `unqualified.sa`, and
`refuse/*.sa` + `refuse/mods/*.sa` (16 probes and the four broken modules they
point at).

## Two fixture bugs worth recording

Both were *my* fixtures, not the tool, and both were caught the moment the
generated program hit a real backend:

* `struct Point { x: num }` — struct fields in this dialect are bare names;
  annotations are refused (`docs/TYPES_ROADMAP.md`).
* `make scaled(v) { give v * scale }` — a function cannot read a top-level
  `hold`; globals are not captured. The module fixture now passes the factor
  as a parameter, and the module-level `hold` is read at the top level
  instead, which is where the rewrite has to prefix it anyway.

The lesson for the gate design: the pass's output is only interesting if a
backend compiles and runs it, so the gate runs it on three.

## What this does not do

* It does not change the language, the compiler or the `use` splice.
* No module scope at compile time, no export lists, no private visibility, no
  import-once cache, no version resolution, no cyclic-module linker, no search
  path. A module is one file, named by a path relative to the working
  directory.
* Nothing here promises a future bootstrap release will absorb any of it.
  STATUS row 10 now reads "not planned in the compiler; implemented one layer
  out", which is exactly what is true.
