# Bootstrap modules: textual `use` in the compiler, namespacing in a pass

Two layers, and the difference matters:

* **The compiler** (seed-min, gen2, native_aot) has textual `use` splicing and
  one flat name table. That has not changed, and the 2026-10-16 decision
  below still describes it exactly.
* **`tools/sxmod.sa`** (2026-10-23) is a source-to-source pass that gives
  modules real namespaces *before* the compiler sees the program. It is
  written in Sayanox, compiled by gen2, and gated by `make test-sxmod`. See
  "Namespaced modules as a pass" below.

So: there is still no module identity *in the language*. There is now a
supported way to get it, and it is a separate program you run first.

## The 2026-10-16 decision, unchanged

Module namespacing and import aliases are **not planned for the bootstrap
dialect**. The maintained seed-min, Gen2 and native paths provide textual
source splicing only. No module-identity feature is implemented in the
compiler.

## Supported contract

```sayanox
use "stdlib/list_algo.sa"
hold values = [1, 2, 3]
show la_lower_bound(values, 2)
```

The quoted path selects source text to splice before ordinary compilation.
Definitions participate in the including program's ordinary name tables;
there is no separate module scope, export list, private visibility or qualified
symbol table. Keep explicit public prefixes (`la_`, `t_`, `nu_`, etc.).
Changing a path or copying a file does not rename its declarations or give them
a new identity. Repeated inclusion is not promised to be an idempotent import;
there is no import-once/module cache contract. Use nesting is capped at eight;
this is not a cyclic-module linker. Search-path details remain those of the
existing backend expanders; no new resolver is introduced here. In particular,
no general per-import directory stack, package version resolver or canonical
module identity is promised by this page.

`make test-use` retains its positive direct/nested splice and negative
missing/unquoted path checks. The existing stdlib gates also exercise real
`.sa` splices; the four bootstrap gates remain the integration contract.

## Unsupported — do not emulate with path rewriting

There is no `use "file.sa" as alias`, `alias::name`, namespace declaration,
qualified import, re-export or namespaced package resolution feature. A dotted
expression in supported code denotes a struct field chain, not a module member.
A path prefix is not a symbol prefix. For example, placing identical files at
`left/math.sa` and `right/math.sa` does not make two independent `math` scopes.

These forms are outside the bootstrap language contract, not deferred syntax
promised for a later bootstrap release. No alias parser or source rewrite was
added *to the compiler*. Existing preprocessors can differ in diagnostics or
ignore trailing text on a `use` line; incidental parsing/ignored suffixes must
**not** be treated as working aliases. This decision does not claim uniform
new refusal diagnostics for every alias-looking spelling.

What you can do instead is the next section: run `tools/sxmod` first, and
hand the compiler a flat program it already understands.

## Namespaced modules as a pass (`tools/sxmod`, 2026-10-23)

```sayanox
module math from "selfhost/sxmod_tests/math.sa"
module text as t from "selfhost/sxmod_tests/text.sa"

show math.add(2, 3)        // 5
show t.add("a", "b")       // ab
show math.scale            // a module-level `hold`, read by name
```

```sh
make tools/sxmod
./tools/sxmod selfhost/sxmod_tests/app.sa /tmp/app.sa
./selfhost/gen2 /tmp/app.sa /tmp/app.c      # ordinary bootstrap Sayanox
```

The pass rewrites every module declaration to `<module>__<name>` and every
`alias.member` to the same prefixed name:

```sayanox
make math__add(a: num, b: num) -> num { give a + b }
make text__add(a: str, b: str) -> str { give concat(a, b) }
show math__add(2, 3)
show text__add("a", "b")
```

**Why this is not cosmetic.** Both fixtures declare `add`. Spliced flat with
`use`, that program cannot be compiled by anything: seed-min refuses with
*duplicate function name*, the C gen2 emits is rejected by `cc`, and
native_aot refuses with *declared twice*. `make test-sxmod` asserts all three
failures first, then compiles the namespaced version on all three backends
and compares stdout. The negative control is the point of the gate.

### The contract

| | |
|---|---|
| syntax | `module NAME from "PATH"`, or `module NAME as ALIAS from "PATH"` |
| placement | all `module` lines come before the first statement |
| exports | exactly the module's top-level `make`, `hold` and `struct` names — everything top level is exported, there is no private visibility |
| prefix | `NAME__member`; the module name must start with a lowercase letter so a prefix cannot collide with the compiler's `Struct__tag` generic specialisations |
| qualified use | `alias.member` only. A member is **not** visible unqualified — after the pass `add(2, 3)` names nothing and the compiler says so, which the gate checks |
| left alone | strings, comments, locals, parameters, struct fields, and every dotted expression whose head is not a declared alias (`point.x` stays `point.x`) |
| nesting | none: a `module` or `use` line *inside* a module file is refused |
| determinism | the same input gives byte-identical output |

### Refused, each with a diagnostic and exit 1

| Program | Diagnostic |
|---|---|
| `math.subtract(…)` | module 'math' has no member 'subtract' |
| `show math` | 'math' is a module alias, not a value; write alias.member |
| two modules, one alias | the alias 'math' is already in use |
| a module declaring `f` twice | 'f' is declared twice at the top level of this module |
| a path that cannot be read | cannot read the module file '…' |
| `from selfhost/math.sa` | the module path must be in double quotes |
| `module math "path"` | a `module` line needs `from "path"` |
| a `module` line after a statement | all module lines come first |
| `module Math from …` | the module name must start with a lowercase letter |
| a module with no top-level names | declares nothing at its top level |
| a program with no `module` line | nothing to namespace |
| `use` in a namespaced program | compose with `module` instead |
| `use` inside a module file | its names would stay unprefixed |
| a `module` line inside a module file | nested namespacing is not claimed |
| a parameter shadowing a module name | rename the parameter |
| a local `hold`/`for` shadowing a module name | rename the local |

The last two deserve a word. If a module declares `hold total` and one of its
functions takes a parameter called `total`, a textual rewrite has to decide
what a bare `total` means inside that function. Guessing there is a
miscompile, so the pass refuses the file and names the line. That restriction
is the price of doing this soundly in a pass rather than in the compiler.

### What it is not

Not a change to the language, the compiler or `use`. No separate module scope
at compile time, no export lists, no private visibility, no import-once cache,
no version resolution, no cyclic-module linker, no search path (the path is
taken as written, relative to the working directory). A module is one file.
Nothing here promises that a future bootstrap release will absorb any of it.

A sound expansion would need canonical module identity, import scopes,
qualified symbol resolution across calls/types/fields/generic specializations,
collision/visibility rules and tests across all backends. A textual
find-and-replace or path rename cannot establish those properties. Such a
feature would be a separately designed language expansion, not a bootstrap
compatibility trick.

No pure-min splice implementation was changed. Gate logs for this decision
and the independent native IR-listing audit are in
[`gate-logs/2026-10-16-ir-modules/`](gate-logs/2026-10-16-ir-modules/).
