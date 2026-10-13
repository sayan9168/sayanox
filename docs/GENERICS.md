# Generics: type parameters, monomorphised

Status (2026-10-12): **generics with one or more type parameters are the
supported and documented form.** `make twice<T>(a: T) -> T` and
`make pair<A, B>(a: A, b: B) -> A` both compile; every type parameter is
resolved at each call site from the argument that uses it, and the whole
generic is specialized by value kind. Seed-min/gen2 emit ordinary C; native
emits x86-64 Linux machine code.

## The supported form

```sayanox
make twice<T>(a: T) -> T {
  give a
}
make pair<A, B>(a: A, b: B) -> A {
  give a
}
show twice(7)          // 7
show twice("ok")       // ok
show pair(1, "x")      // 1
show pair("x", 1)      // x
```

* One or more type parameters, named in a comma-separated list in angle
  brackets after the function name: `make NAME<T>(...)` or
  `make NAME<A, B>(...)`, up to `<A, B, C>` and beyond.
* Every parameter's type and the return type must name one of the type
  parameters. A parameter typed `num`, a return type that names nothing, or a
  return type naming an undeclared parameter is **reported as an error**
  (`must be written with type parameters used by every parameter and the
  return type`), never silently compiled.
* Each type parameter stands for one of the three value kinds: `num`, `str`,
  or a double list.
* Type-parameter names are single characters or identifiers; a generic may
  have up to 10 type parameters in gen2 (its tables use single-character
  indices); seed-min supports up to 8.

## How a call site picks the kinds

The kind of a type parameter is the kind of the **first argument whose
declared parameter uses it**:

* a string literal, or a variable declared `str`, gives `s`;
* a list literal, or a variable declared `list`, gives `l`;
* anything else gives `n`;
* the fixed kinds of the builtins (`concat` → `s`, `len` → `n`, `push` → `l`,
  …), the declared return kinds of ordinary functions, and — for a nested
  generic call — that call's own arguments, are followed too, so
  `give pickb(x, x)` and `show twice(twice("z"))` work.

With one type parameter this is exactly the old "kind of the first argument"
rule, which is why single-parameter generics keep the names `NAME__n`,
`NAME__s`, `NAME__l`.

## The specialised name

A copy is named `NAME__` followed by one kind character per type parameter,
in declaration order:

| generic | call | copy |
|---|---|---|
| `twice<T>` | `twice("x")` | `twice__s` |
| `pair<A, B>` | `pair(1, "x")` | `pair__ns` |
| `pair<A, B>` | `pair(s, xs)` | `pair__sl` |
| `three<A, B, C>` | `three(1, "x", xs)` | `three__nsl` |

Each copy gets a prototype before any use, and is emitted **once** however
many call sites ask for it. An unused generic emits nothing.

The emitted C signature is per-parameter, not one type for the whole function:

```c
static double  pair__ns(double a, char * b);   /* A = num, B = str, -> A */
static char *  pair__sn(char * a, double b);   /* A = str, B = num, -> A */
static sx_list *  pair__ls(sx_list * a, char * b);
```

A generic that calls another generic inside its body specialises the callee
with the kinds it was given itself (`usefirst<A, B>` calling `pair<A, B>`
produces `pair__ls` inside `usefirst__ls`), and `hold v: T = callee(...)` in
such a body knows the callee's result kind, because the callee's kind is
recorded as soon as the nested call is queued.

## Backends

* gen2 and gen1_min implement this; both produce byte-identical C
  (`make test-generics` diffs the two outputs).
* It is a full-language feature: seed-min and the pure-min dialect do not read
  `make NAME<...>` at all and reject the program.
* native compiles a generic over **numbers**: each type parameter is `num`, so
  `make twice<T>(a: T) -> T` is one numeric function (`make test-native-generics`).
  A call that passes a string or a list is refused with `generics are not in the
  native subset for strings and lists`; a generic must be fully typed (every
  parameter and `-> T`) and every parameter must be a type parameter, as on gen2.

## Verified by

`make test-generics` covers, on gen2 with gen1_min agreement:

* the single-parameter program (`pickb`/`twice`/`quad`/`wrap`/`unused` over
  num, str and list, nested and cross-generic calls, one copy per kind, every
  call prototyped, an unused generic emitting nothing);
* a multi-parameter program: `pair<A, B>` (returning `A`), `swap<A, B>`
  (returning `B`), `three<A, B, C>` (returning `C`), `usefirst<A, B>` calling
  `pair<A, B>` and binding the result in a `hold`, over the kind combinations
  `nn`, `ns`, `sn`, `ls`, `ln`, `sl`, `nsl` — each copy asserted to appear
  exactly once, no `#error`, no implicit declaration;
* two rejection cases: a parameter that does not use a type parameter, and a
  return type naming an undeclared one.

## What this does not claim

* No trait or bound system: a type parameter has no constraints beyond the
  three value kinds.
* No type inference beyond the call site's argument kinds, and no inference
  for a type parameter that no argument pins down (it falls back to `num`).
* No bounds on a *struct* type parameter, and no generic lists of arbitrary
  element types: lists remain double-only (see [`SYNTAX.md`](SYNTAX.md)).
  Generic **structs** do exist since 2026-10-13 — `struct Box<T> { v }` is a
  template and each instantiation is its own concrete struct (`Box<num>` is
  `Box__n`, `Box<str>` is `Box__s`, `Pair<num, str>` is `Pair__ns`: the
  function-mangling suffixes), on all three backends, with `num` or `str` as a
  type argument. `make test-generic-structs` pins the parity fixture and the
  five refusals; [`TYPES_ROADMAP.md`](TYPES_ROADMAP.md) records the model and
  what is still missing.
* Kinds are per *value kind*, not per declared type: `A` and `B` can both be
  `num` without any distinction being made.

## Backend parity (decision, 2026-10-10)

Generics are a **gen2 feature**. Parity across backends means the same answer
on each: the same program is either compiled or refused, never miscompiled.

| Backend | `make NAME<T>(...)` | Checked by |
|---|---|---|
| gen2 (and gen1_min, which builds it) | compiled (monomorphised) | `make test-generics` |
| seed-min | demand-driven num/str/list specializations; typed bodies | `make test-seed-generics`, `make test-generics` |
| native (`native_aot`) | numeric, string and double-list specializations | `make test-native-generics`, `make test-native-strgen`, `make test-native-listgen` |

## Seed specialization engine (2026-10-12)

Seed-min now registers generic templates and binds type parameters from call
arguments. Every parameter and return annotation must name a declared type
parameter; every type parameter must be inferable from at least one argument.
Two arguments using the same type parameter must have the same kind. Struct
arguments, unresolved types and mixed concrete/type-variable signatures fail
explicitly rather than becoming numeric parameters.

Each concrete signature gets one generated, fully typed definition. A finite
worklist appends those definitions before C emission, discovers nested and
recursive requests, and reuses already registered specializations (including
mutual recursion). Prototypes precede definitions. Local `hold x: T` annotations
are substituted token-wise, never inside strings/comments or ordinary variable
names. The normal typed-body checks apply to each instantiated body. Unused
templates do not produce C bodies. This is not annotation erasure.

Limits: 8 type parameters, 16 value parameters, 512 total function-table
entries including templates and generated variants, and 8 MiB expanded source
(the individual template-body expansion also has a bounded allocation).
`_sx_gen_` is reserved. Bodies retain the seed typed-function contract:
isolated locals, no global capture, structurally complete return paths, supported
builtins only. Explicit type arguments at calls are not implemented. Generic
*structs* are, with the same per-kind mangling: `struct Box<T> { v }` gives
`Box__n` for `Box<num>` and `Box__s` for `Box<str>`
([`TYPES_ROADMAP.md`](TYPES_ROADMAP.md)). Calls that cannot be resolved during pre-emission checking fail
instead of adding undeclared C functions during emission.

`test-seed-generics` checks ordinary num/str/list and multi-parameter calls,
numeric recursion, list aliases and call-source loops across all three
backends. Extended seed/native fixtures cover deeper nested generic calls
and a string-only recursive template; a seed-only scope fixture covers
mutual recursion, local annotations, and safe handling
of comments/strings/type-variable names. The extended fixture now also passes on gen2 after its request-separator
and template-record lookup fixes. Native passes it after its unused
numeric-base emission was replaced with demand-driven emission. Scope/token
edge cases in the separate seed scope fixture still have their own boundary. The existing
`test-generics` multi-parameter fixture now also runs through seed-min;
its other fixture still uses unsupported seed builtin `numstr`.

Tests check deterministic emitted C, one definition per concrete kind, no
unused instantiation, conflicting kinds, malformed signatures, body/return
mismatches and the specialization limit. Native's existing generic tests
remain unchanged. Generic structs require the concrete type identities and
GC/layout work in [TYPES_ROADMAP.md](TYPES_ROADMAP.md).


## Native annotated locals and generic body demand

`test-native-generic-local` now verifies num/str/list hold annotations at top
level and in functions, plus `hold local: T` in concrete generic bodies.
Collection, inference and emission use the same annotation parser; inferred
initializers and later assignments must retain the declared kind. Unknown
and mismatched annotations are errors, not annotation erasure.

Native no longer emits an unconditional numeric version of every template.
Requested numeric versions and other specializations share the pending-body
worklist, including calls discovered in emitted bodies. A string-only generic
body is therefore checked as a string body, without a spurious numeric
failure. Unused template bodies are not emitted/checked; their headers must
still parse. Invalid bodies are rejected when instantiated. The old generic
multi-parameter/local-annotation fixture now passes on native too.


## Gen2 nested-request queue repair (2026-10-12)

Nested bodies can enqueue consecutive records with both a trailing and a
leading separator. Gen2 now skips empty separators before reading the next
name. It also searches only template record headers, not parameter/body
fields that might happen to equal a function name. Negative type-table
indices are guarded before indexing kind strings.

The previous identity(identity(value)) extended fixture now compiles and
prints the hand-computed output. A second regression exercises repeated
nested calls across num/str/list specializations and a function name that
matches an earlier template's parameter name. Seed/native output matches;
gen1_min and gen2 produce byte-identical C for the extended fixture.
This closes the recorded queue crash, not every possible generic inference
edge case. Generic structs and general list-expression lowering remain open; complete
list-literal returns and typed numeric-expression list arguments are now supported
within the boundary documented in SYNTAX.md.


Instantiated generic functions now use structural return-path checking on all
three backends. Exhaustive returning when/elif/else chains are accepted without
an extra terminal give; a missing arm is an error. Only reachable instances
are checked where specialization is demand-driven. Generic structs and
concrete struct type identities remain separate, unfinished work.


Calls inside inline numeric-list elements now consume concrete return and
parameter-kind metadata, including newly requested generic instances. Parameter
kinds are recorded at specialization request time, not only after body emission;
wrong nested-call arity/kinds are rejected. This does not implement generic
struct identities or expand the generic declaration grammar.


### Postfix argument inference (2026-10-13)

For arguments resolved by the typed expression parser, specialization uses
the whole expression's kind: `identity([30, 40][1])` selects `num`, not `list`.
Grouped literal indexing and nested numeric/string-field indexing retain their
resolved kind. Multi-parameter argument scanning balances list/brace/group
delimiters, so commas inside `[1, 2]` do not start a new function argument.
`test-list-postfix` checks seed/gen2/native output parity, including a second
type parameter after an indexed list literal. Unresolved expressions still
use the existing classifier; this does not claim universal inference. Generic
structs (concrete struct specializations) landed in a later increment — see
[`TYPES_ROADMAP.md`](TYPES_ROADMAP.md).
