# Incremental types: implementation constraints

Status: seed hold annotations and fully typed num/str/list functions and generic function specialization implemented; generic structs remain design-only (2026-10-12).

The runtime kinds are double, string, double-list, and named literal-typed
struct. Function generics specialize by kind, not arbitrary structural type.
Gen2 already accepts optional `hold n: num = 4`, `hold s: str = "abc"`, and
`hold xs: list = [1, 2]` (`test-full-lang`). Seed-min now accepts these annotations outside `make` (including blocks
outside functions) and inside fully typed functions, tested by
`test-seed-hold-types` and `test-seed-typed-functions`. Do not strip annotations as a compatibility transformation:
`hold n: num = "x"` must never become an inferred string silently.

## Why generic structs are not implemented here

The seed learns a struct's field layout from literals before emitting its C
typedef. A single global definition owns that layout. Native code similarly
needs a concrete field layout and pointer-kind information for its collector.
Treating `Box<num>` and `Box<str>` as the same definition would confuse field
loads and GC roots. Function specialization by num/str/list alone cannot
provide the identity of `Box<num>` versus `Other<num>`.

A safe implementation needs:

1. A concrete type identity (struct declaration plus fully substituted type
   arguments), separate from the current coarse value-kind tag.
2. Per-instantiation field layouts; never mutate a template's layout when
   processing a literal. Reject unresolved and conflicting field types.
3. Ordered C typedefs and native field/GC descriptors for every reachable
   instantiation; a cycle check for recursive value layouts.
4. Kind checking at calls, returns, assignments and field writes. No implicit
   pointer/number casts and no fallback-to-num for unknown type names.
5. A finite specialization worklist with recursion/cycle diagnostics and
   stable ordering, so gen3/gen4 remain byte-identical.

Acceptance tests must mix two specializations in the same program, copy and
nest them, recurse through functions, keep string fields alive across GC,
and reject cross-specialization assignments. Run all four bootstrap gates
before considering the syntax supported. Until then use distinct concrete
struct names; generic structs remain unimplemented on all three backends.

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
