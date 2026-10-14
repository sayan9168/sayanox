# Incremental types: implementation constraints

Status: seed hold annotations and fully typed num/str/list functions and generic function specialization implemented; **generic structs are implemented on all three backends** (2026-10-13) as one mangled concrete struct per instantiation, gated by `make test-generic-structs` with a shared parity fixture and five named refusals. What is still missing is listed under "What is still missing" below.

The runtime kinds are double, string, double-list, and named literal-typed
struct. Function generics specialize by kind, not arbitrary structural type.
Gen2 already accepts optional `hold n: num = 4`, `hold s: str = "abc"`, and
`hold xs: list = [1, 2]` (`test-full-lang`). Seed-min now accepts these annotations outside `make` (including blocks
outside functions) and inside fully typed functions, tested by
`test-seed-hold-types` and `test-seed-typed-functions`. Do not strip annotations as a compatibility transformation:
`hold n: num = "x"` must never become an inferred string silently.

## Generic structs: what is implemented (2026-10-13)

`struct Box<T> { v }` declares a **template**: parameter names and field names,
and no layout. A template never becomes a struct of its own — it is recorded in
a separate table, and each *instantiation* becomes an ordinary concrete struct
under a mangled name:

| Instantiation | Mangled name | Emitted layout |
|---|---|---|
| `Box<num>` | `Box__n` | `typedef struct { double v; } Box__n;` |
| `Box<str>` | `Box__s` | `typedef struct { char *v; } Box__s;` |
| `Pair<num, str>` | `Pair__ns` | `typedef struct { double a; char *b; } Pair__ns;` |

Those are the suffixes generic **functions** already use, so the mangled name
*is* the type identity: `Box__n` and `Box__s` have their own field kinds, their
own typedef and — on native — their own GC block descriptor, and they can never
share a field slot. Creation is idempotent (look the mangled name up first), so
repeated rounds of literal scanning agree on struct indices and gen2/gen3 stay
byte-identical.

Measured against the five-point list this document used to carry as the price
of a safe implementation:

1. **Concrete type identity** — done: template plus fully substituted type
   arguments, mangled to one name per instantiation.
2. **Per-instantiation layouts** — done: a template's field list is copied into
   each instantiation and never mutated, and the template itself is not
   registered as a struct, so no literal can give it a layout.
3. **Ordered typedefs and native field/GC descriptors** — done for the
   supported forms: instantiations are created in first-use order, typedefs are
   emitted with the other structs, and native records the pointer-kind map per
   instantiation for its collector. There is no cycle check because a recursive
   layout cannot be spelled yet (see below).
4. **Kind checking at every boundary** — partly done: the type argument fixes
   the field kind at the literal, so one instantiation used with two kinds is
   refused by all three backends. Struct-typed `hold` annotations turned out
   to already exist on **gen2** (measured 2026-10-13, correcting the earlier
   claim that no backend has them): `hold p: Pt = Pt { 1, 2 }`,
   `hold q: Pt = p` and even `hold b: Box__n = Box<num> { 7 }` compile and
   run, and `hold p: Pt = 5` is refused with `'p' is declared Pt but the
   value is a number`. seed-min (`unknown hold type: seed-min supports num,
   str, list`) and native (`hold 'p': unknown or unsupported type 'Pt'`)
   refuse the same syntax by name, because their `hold` types are the
   scalars. All of this is pinned by `make test-type-refusals`. Calls and
   returns still cannot be checked against a struct type on any backend.
5. **A finite specialization worklist** — done by construction: instantiation
   happens on demand at a literal site, is idempotent and needs no recursion
   (nesting is refused), so the order is stable and gen3 is reproducible.

Per backend:

* **seed-min** (`selfhost/seed/sxc_seed_min.c`): a `GStruct` template table
  beside the concrete `StructDef` table; `parse_type_params`,
  `skip_struct_decl` and `instantiate_gstruct` are shared by all four places
  that walk a struct declaration, and instantiation happens where a struct
  literal is parsed, so `collect()`'s own right-hand-side scan learns the same
  mangled type that the assignment emits.
* **gen2** (`selfhost/compiler_min.sa`): a pre-pass — `gxscan` collects the
  templates, `gxpass` rewrites every instantiation to its mangled name and
  seeds `sdefs` with the instantiations in first-use order — so the existing
  struct machinery (field kinds, `ftypes`, typedefs) only ever sees a concrete
  struct. Both scans walk *positions* and build a string only once an
  occurrence is confirmed; see "Self-host memory ceiling" in
  [`STATUS.md`](STATUS.md) for why that is not a style choice.
* **native** (`selfhost/native_aot.c`): a `GSDef` template table plus
  `gs_find`/`gs_instantiate`, called at both struct-literal sites (kind packing
  and emission). The type arguments seed the per-field kind map that the
  collector's pointer scan uses, so a `Box<str>` field is a GC root and a
  `Box<num>` field is not — measured with a `Box<str>`/`Box<num>` pair kept
  alive across 3000 allocating iterations (`show gc_runs()` reports 2 and both
  fields survive).

`selfhost/generic_struct_box.sa` is the shared parity fixture: `Box<num>`,
`Box<str>`, a second `Box<num>` and `Pair<num, str>` in one program, printing
`7 seven 8 7 9 nine` byte-identically on seed-min, gen2 and native.
`make test-generic-structs` pins that fixture, the three mangled typedefs in
the generated C, the five refusals below, and the two older sections (the
concrete-name workaround and the dotted-field-read divergence).

### Refusals, measured 2026-10-13

| Program | seed-min | gen2 | native |
|---|---|---|---|
| `Box<num, str> { 7 }` (one parameter) | `Box takes 1 type argument, got 2`, exit 1 | `#error sayanox-min: undefined name: Box` | `struct 'Box' takes 1 type argument, got 2`, exit 1 |
| `Box<NumBox> { n }` (a struct as a type argument) | `a type argument must be num, str or list (got 'NumBox'); a struct name as a type argument is not implemented`, exit 1 | `#error sayanox-min: undefined name: Box` | the same sentence as seed-min, exit 1 |
| `Box<list> { xs }` (no backend has a list-typed struct field) | `a struct field cannot hold a list`, exit 1 | `#error sayanox-min: undefined name: Box` | `struct 'Box__l' field 'v' cannot hold a list (seed-min/gen2 reject this)`, exit 1 |
| `Box { 7 }` (a bare template name) | `Box is a generic struct: write Box<num> { ... } with one type argument per type parameter`, exit 1 | `#error sayanox-min: unexpected '{' (expected the end of the statement or a new statement)` | `'Box' is a generic struct: write Box<num> { ... } with one type argument per type parameter`, exit 1 |
| `Box<num> { 7 }` and `Box<num> { "seven" }` | `Box__n field 'v' is num (its type argument says so), the literal gives str`, exit 1 | `#error sayanox-min: struct field is used with two different types (string vs number)` | `struct 'Box__n' field 'v' is a number (its type argument says so), the literal gives a string`, exit 1 |

All three backends refuse all five. seed-min and native name the problem; gen2
refuses three of them through its general undefined-name/stray-token errors, so
`make test-generic-structs` pins gen2's *failure* for those and pins its
wording only where gen2 names the problem (the two-kinds case). Freezing gen2's
weak wording in a gate would make it harder to improve, and no gate claims it
is good.

### What is still missing (measured 2026-10-13)

* **Nested instantiations** — `Box<Box<num>>` is refused: a struct name is not
  an accepted type argument on any backend, so an instantiation cannot contain
  another (`make test-type-refusals` pins the refusal on seed-min, gen2 and
  native; seed-min and native name the problem, gen2 refuses via its general
  `undefined name: Box`). seed-min additionally requires a nested concrete
  struct to be declared before the struct that holds it.
* **A struct or a list as a type argument** — refused everywhere. A list-typed
  struct field does not exist in any backend; a struct-typed one exists only as
  a declared concrete name.
* **gen2's diagnostics for a bad type argument list** — it refuses, but as
  `undefined name: Box` or `unexpected '{'` rather than naming the template.
  The name is known to the pre-pass and not to the two walker sites that report
  those errors, and threading it there did not fit the byte budget this
  increment had left (see "Self-host memory ceiling" in
  [`STATUS.md`](STATUS.md)).
* **gen2 learns field kinds from literals** — with a *single* literal whose
  kind contradicts the type argument (`Box<num> { "seven" }` and nothing else)
  gen2 accepts it and gives `Box__n` a string field, where seed-min and native
  refuse. A second literal of the other kind is refused by all three. Closing
  this needs the field's *index* at gen2's two `ftypes` write sites.
* **Struct-typed annotations are gen2-only** — `hold b: Box__n = Box<num> { 7 }`
  works on gen2 (above), so a cross-specialization assignment *can* be
  expressed there, but seed-min and native refuse every struct-typed
  annotation, so the spelling is not portable. seed-min refuses all struct
  reassignment.
* **Struct field annotations** — `p: Pt` inside a struct body is refused on
  all three backends since 2026-10-13 (`struct field annotations are not
  supported: write just the field name`, `test-type-refusals`). Before that
  it silently registered `Pt` as an extra field and changed the literal
  arity — the worst failure mode in this file. A literal after the colon
  (`k: 2`) remains the old tolerated spelling and registers field `k` only.

The adjacent divergence below predates this increment and is unchanged —
`make test-generic-structs` still pins it:

* a **dotted field read inside a struct literal** — `hold a2 = NumBox { a.v }` —
  is accepted by seed-min (prints the field's value) and refused by gen2
  (`#error sayanox-min: struct/list literal value must be a number, string,
  name, or nested struct`) and by native (`struct field 'NumBox.v' is used with
  two different types`). Portable spelling: bind the field first
  (`hold v = a.v`), then use the name in the literal.

This is a diagnostic increment, not a type-system increment: no layout, no type
identity and no specialization worklist was added, and the five requirements
above are all still open.

## Implemented seed hold-annotation increment

Collection, literal scanning and emission now share `hold_annotation()`.
The declared kind is stored separately from inference; collection preserves
that storage kind, and the full expression parser checks initializers and
later `hold`/bare assignments against it. Unknown names, incompatible
reannotations and kind mismatches are compiler errors, not C pointer casts.
The portable success fixture is checked against gen2 output; rejection tests
cover num/str/list mismatches and unsupported annotations.

Limits: annotations inside legacy untyped `make` are explicitly refused.
Legacy parameters may not shadow annotated globals; fully typed functions
have isolated environments and can reuse those names. Generic structs,
struct annotations and bare struct assignment are not added. This is not a
full inference rewrite or a native ABI change.

## Fully typed function increment

An ordinary signature table records each parameter and return kind, with
shared parsing in collection, scanning and emission. Prototypes and calls
use that table, including forward calls. Signatures are either fully typed
num/str/list with explicit return type, or legacy untyped numeric. All typed
calls check counts/kinds, including nested argument expressions in main.

Typed bodies have isolated parameters/locals, stable local kinds, optional
hold annotations, conditions, while/for and early returns. New block-local
bindings expire at block end; existing outer bindings are reassigned by
repeated hold. The subsequent structural return-path increment accepts either a returning
suffix or an exhaustive returning when/elif/else chain, including nested
branches. Functions with an explicit return signature may not fall through.
Loops are conservatively treated as possibly executing zero times; no
constant-condition or termination proof is claimed. String parameters are copied on
entry for alias-safe reassignment; lists share references. Seed allocations
remain uncollected. Generic specialization now reuses this typed-body
contract (see GENERICS.md); global captures remain absent.

`test-seed-typed-functions` compares seed/gen2 typed calls, recursion,
string/list alias behavior, control flow and typed-function for loops. A
former seed-only fixture covers sibling-block names, typed forward calls
and boolean literal arguments; these cases now also pass on gen2 with
dedicated regressions. Native parameter reassignment is now covered by test-native-param-reassign;
function-local for now has frame-local binders/hidden state and recursion/GC
coverage. Native list growth now preserves aliases via GC-traced forwarding
links; test-native-for-functions and test-native-list-alias cover these paths. `test-typed-sig`
and `test-stdlib` retain separate supported three-backend comparisons.


Native now accepts num/str/list hold annotations at top level and inside
functions, and bound type variables in specialized generic bodies
(`test-native-generic-local`). This also promotes the original annotated
function-local loop fixture to native coverage. Native generic bodies are
emitted on demand rather than forcing an unused numeric specialization.
None of these changes provides generic struct type identities or layouts.


Gen2 now isolates function parameter/local tables and restores the incoming
name-table lengths when a nested function block closes. This fixes valid
sibling-branch declarations of different kinds and same-named globals versus
function locals. The compiler's existing top-level flat declaration contract
is intentionally unchanged. That declaration-tracking increment did not supply reference diagnostics or
native sibling-kind scoping; gen2 reference checking is now added separately. Structural return-path
checking has since been added separately (below).

Gen2's subsequent bounded list-expression increment supports complete literal
returns through existing hold/list checks, and numeric-expression list arguments, now including variables, checked
nested calls, modulo/comparisons and indexing. General list postfix/struct-field
expressions, whole-program expression/type analysis and generic structs remain
open. See SYNTAX.md for the exact boundary.
A caller-frame GC anchor fixes the observed -O0 root-loss bug; focused -O0/-O2
compiler/program tests and all four bootstrap gates pass. This does not expand
the collector's conservative, target-dependent portability guarantees.


## Structural return-path checking

`test-return-paths` covers seed, gen2 and native. Typed num/str/list functions
and instantiated generic functions must return on every structurally reachable
fall-through path. A give guarantees a return; sequential suffixes can finish
otherwise unreturned paths; a branch chain guarantees a return only if every
arm does and a final else/otherwise exists. Nested branches compose. The seed
no longer insists that the last top-level statement itself be give.

The scanner skips quoted/escaped text, comments and balanced expression
brackets/braces. It is separate from ordinary expression and type validation,
not a replacement for it. Loops never establish a guaranteed return, even
`while true`; use a returning suffix. Nesting beyond 128 cannot establish a
proof. Legacy untyped function behavior is unchanged. This conservative
structural analysis is implemented; arbitrary termination/constant-condition
reasoning, full undefined-name checking, generic structs and the remaining
list-expression extensions are not.


## Gen2 reference-resolution increment

Value and call names are now checked before lowering each supported expression
statement category, against the active value tables and collected signatures.
This covers initializers, arithmetic, nested calls, list/index expressions,
assignments, conditions, loops, returns and instantiated generic bodies.
Unknown names/callees emit explicit diagnostics. Field labels/selectors,
quoted/commented text, builtin-like variable names, string iterators and
forward/generic calls have positive regressions.

`test-name-resolution` is part of test-typed-sig/native-test. Function-local
scope boundaries are honored. Legacy top-level flat bindings remain unchanged;
definite assignment, full expression type analysis and top-level lexical-scope
redesign are not claimed. Generic structs and the outstanding inline-list
expression extensions remain unimplemented.


## Typed inline numeric-list expressions

A typed recursive precedence parser now lowers inline lists before lexical
kind tables expire. It checks numeric results, nested call arity/kinds, scalar
operators and index operands; specialization requests now record parameter
kinds early enough for this check. Strings/lists may be intermediate values
consumed by matching calls, not final numeric-list elements. Generated double
temporaries preserve the list varargs ABI and left-to-right element evaluation
in the newly lowered inline path. Allocation/evaluation remain in loop and
branch expressions. Native list inference/counting now accepts comparisons,
matching its existing comparison emitter.

Shared fixtures match seed/gen2/native. Seed sequencing now has an explicit
linked builder stack and passes the shared order fixture at O0/O2; nested and
recursive constructors have a separate regression. Gen2's legacy named-hold
and direct-literal-return constructors have not been migrated to the new
sequenced lowering.

The parser now resolves named/nested struct fields through concrete field
metadata. Checked whole-call parsing accepts numeric postfix results, grouped
list literals and indexed list-returning calls as arguments. Generic argument
inference uses a resolved expression kind when available rather than assuming
that a leading list token means a list-valued argument. Unknown fields,
nonstruct selectors and parameter-kind mismatches have seed/gen2 regressions.

Inline-only string runtime dependencies have their own regression. Arbitrary
literal-headed/grouped expressions outside these checked call paths, generic
structs, full expression type inference and definite assignment remain open.
