# Sayanox published-language profile v1.0

Normative acceptance profile, 2026-10-29. Scope is the user's agreed **currently
published language**, including documented gen2/gen3 extensions, not proposed
TYPES_ROADMAP features. Acceptance status is separate: see STATUS.md. Merely
having this file, a dispatcher, or a successful source-to-C exit is not acceptance.

## 1. Sources and conflict resolution

This profile normalizes SYNTAX.md, TYPES.md, GENERICS.md, BUILTINS.md and the
compiler layer of MODULES.md. Their examples, positive forms and explicit
current context restrictions are incorporated. Dated shared-seed/native tables
are historical backend coverage, not restrictions on the C-output compiler.
Later explicitly implemented nested/list generics supersede older scalar-only
refusal records. The compiler's own implementation may stay in the pure-min
intersection without restricting accepted published user programs.

The two inventories FULL_LANGUAGE_CASES_V1.tsv and FULL_LANGUAGE_BUILTINS_V1.tsv
are part of this version. Each clause has positive, refusal and boundary case
references and executable gates. Each public builtin/spelling has a signature
and a runtime case. The validator requires the complete independent ID sets;
missing/duplicate IDs, missing case references and modified pinned artifacts
are errors. No OPEN row or test summary alone closes a clause.

## 2. Grammar and values

The following is an overview; the context restrictions below are normative.
It is not a promise of a universal expression parser in every legacy context.

```text
program       := (use | struct | function | statement)*
binding       := 'hold' identifier [':' kind] '=' value
assignment    := identifier '=' value | field '=' value | index '=' number
output        := 'show' value
conditional   := 'when' condition block (chain condition block)* [otherwise block]
chain         := 'elif' | 'else if' | 'else when' | 'otherwise when'
otherwise     := 'otherwise' | 'else'
loop          := 'while' condition block | 'for' identifier 'in' iterable block
block         := '{' statement* '}'
function      := 'make' name '(' untyped-parameters ')' block
               | 'make' name '(' typed-parameters ')' '->' kind block
               | documented generic function declaration
statement     := binding | assignment | output | conditional | loop
               | 'give' value | 'break' | 'continue' | 'push' '(' list ',' number ')'
kind          := 'num' | 'str' | 'list' | concrete named struct
value         := documented literal, name, field, index, call or operator expression
iterable      := documented string/list expression | number '..' number
```

Source is `.sa`; `//` starts a line comment outside a quoted string. Quoted
braces, range dots and comment markers are data. Escaped quotes/backslashes
must not terminate a string/header. Malformed tokens/literals fail compilation.
Statements follow the documented line-oriented forms; do not infer arbitrary
semicolon statements, closures or bare user calls. `push` is the documented
bare-call exception.

Numbers are doubles. Decimal integers/fractions, unary minus, parentheses and
`+ - * / %` have the documented precedence/left associativity. `%` truncates
operands to integers and diagnoses a zero truncated divisor. Division uses
floating point, not accidental C integer division. Comparisons require
compatible kinds. String comparisons compare contents, including string-returning
calls and compound string operands, never addresses. String `+` concatenates;
number/string mixing is invalid. Word `and`/`or` short-circuit, `and` binds more
tightly; `not` negates a comparison up to the next word logical operator.
Boolean literals are numbers 1/0. Published C-style logical spellings remain
accepted on the C-output path. Conditions have numeric results.

Strings use the documented C-string/byte model (BUILTINS.md): UTF-8 input is
iterated/indexed as bytes, not Unicode code points; embedded NUL terminates
text. Binary data belongs in numeric byte lists/read_bytes/write_bytes.
`chr(0)` therefore produces empty text; nonzero byte codes produce one-byte
text. Negative string/list indexes count from the end. Invalid indexes fail,
not arbitrary memory access. `show` prints one num/str value and a newline;
`write_out` is the separate non-newline stream operation.

## 3. Bindings, calls and control flow

A binding must exist before reassignment/use. `hold` establishes its kind;
assignment cannot change that kind. Preserve the published top-level flat
binding policy, not a new definite-assignment theorem. Function parameters and
function/block locals have the documented expiry rules; they do not leak into
other functions/main. Names and callees use separate lookups; unknown names
and calls cannot become unchecked emitted C identifiers. Forward and mutual
calls remain supported. Functions have no implicit closure/global capture.

Signatures are fully untyped numeric or fully typed, not partly typed. Typed
num/str/list signatures, argument reassignment and checked return paths are
required. A typed function cannot fall through: loops alone do not prove a
return; exhaustive branches or a later unconditional return do. This is a
structural check, not termination analysis. Named-struct parameters/returns
preserve concrete nominal identity. A preceding layout witness is required
before field-reading functions; a pure copy needs no field layout. Bind a
returned struct before selecting fields. Grouped struct holds and generic
struct signature annotations retain their published refusals.

For loops support the documented named/literal/call/field/parenthesized string,
list and numeric-range sources, including typed functions. A literal/expression
source is evaluated once on loop entry; named sources retain the documented
live re-read behavior. Range lower initialization and live upper-bound checks
follow SYNTAX.md. String binders are one-byte strings; list/range binders are
numbers. Existing binders require compatible kinds. Nesting, break and continue
must retain source-loop behavior; hidden implementation temporaries cannot
introduce synthetic loops that intercept them.

## 4. Aggregate, generic and interpolation contexts

Lists contain numbers. Literals, growth, aliases, element assignment, list
parameters/returns and the documented checked postfix/call paths are required.
List aliases refer to the same list. Direct list returns allocate/evaluate at
the return site. Inline numeric-list call arguments evaluate each element
once, left-to-right, including recursive and loop-condition constructors.
Hoist declarations only: allocation/evaluation remain inside the expression
and short-circuit branches. Function temporaries must be automatic locals so
recursive calls cannot overwrite the caller's pending elements.

This does not promise arbitrary literal-headed postfix syntax outside the
published checked paths: direct `hold n = [1][0]` remains outside that increment.
Nested lists, structs as numeric elements and arithmetic on list values are
invalid. Numeric indexes accept the documented checked numeric expression/call
forms, not string/list-returning calls or newly invented universal index syntax.

Structs are nominal, with source-ordered field inference and documented nested
literal layouts and concrete list fields. Whole checked field expressions
(arithmetic, numeric declared calls, string-plus chains) are required. The
published gen2 exclusions for a direct dotted-field initializer and a direct
source builtin initializer remain explicit: bind those results first. This is
not permission to bind results first to hide a promised ordinary builtin call.
List-field conditions retain their separately documented checked-form limits.

Generic functions specialize num/str/list kinds, one or multiple type
parameters, with first-using-argument inference refined by known complete
expression kinds. Every parameter and result of a generic header uses a
recorded type parameter. Preserve scope, forward queues and no duplicate
instances. Generic structs accept num/str/list and nested generic instances.
Concrete non-generic structs/unknown names as type arguments, escaped parameters,
wrong arities, bare templates and literal/type disagreement are refusals. Do
not restore superseded scalar-only exclusions. The existing bounded generic
and structural checking limits remain limits, not new richer type proposals.

Identifier interpolation accepts num/str identifiers, imports, escaping,
adjacent holes and the 16-hole boundary. Unknown/list/struct identifiers,
malformed holes, 17 holes and expression/field/call holes fail. Interpolation
is not applied to use paths/comments and does not broaden struct initializer
syntax. Each hole is evaluated once, using numstr formatting for numbers.

## 5. Runtime and import contracts

The builtin inventory enumerates all 43 canonical public calls. `sx_index` is the
published string-byte indexing API, not an invented `index` alias. `a` is
string-or-list; `v` is string-or-number (the second argument of `concat`);
other signature letters are n=num, s=str, l=list. Results are ordinary expressions in the
published supported contexts. Known signatures constrain arity/kinds; valid
nested use cannot be replaced by a refusal-only test. The complete signature
matrix compiles valid counterparts before testing every argument position
against incompatible num/str/list/struct values and wrong arity.

Runtime contracts and failure results remain BUILTINS.md's specific API rules:
file/byte, stream, process, environment, command, GC and HTTP behavior are all
required. In particular, invalid bit operands outside inclusive 0..2^64 and
shift counts outside 0..63 terminate with a diagnostic **before conversion**.
The 2^64 representable endpoint accommodates a rounded uint64 maximum from
bit_not; larger values/infinity cannot silently saturate. In-range fractional
numeric-to-integer conversions retain truncation. Invalid write_bytes values
return 0 (the API's explicit rule), not a silently wrapped byte; validation
must not destroy an existing destination before rejecting the input buffer.
That specific status API resolves the old collective 'hard error' wording;
it does not turn a status failure into a new process-exit promise.

Streams test EOF as well as successful read/write/flush. Processes retain the
eight-live-child bound, pipes, clean wait status and safe dead handles.
Unset environment variables give empty text. run_command uses the documented
POSIX shell and exit-status convention. exit flushes stdout and terminates;
it cannot execute the following statement. GC is nonmoving/conservative and
must preserve reachable strings/lists through calls, aliases, loops and
returns; false retention is not a precise/bounded-heap promise.

HTTP retains the documented URL/method/status/body/rate/timeout policy. Its
transport is an explicit runtime host dependency, not a bootstrap dependency.
The maintained Sayanox loopback HTTP fixture tests it without an external
network or Python server. Invalid schemes must return before a transport is
started. No remote service availability is a compiler-conformance condition.

`use` is textual splicing into one flat name table, with the current bounded
search/depth behavior and missing/unquoted-path diagnostics. Repeated inclusion
is not import-once identity. Namespaces, aliases, versioned language module
identity and arbitrary per-import directory stacks are not promised. `sxmod`
is a separate maintained pass, not hidden language syntax.

## 6. Acceptance and trust

The compiler is built from the pinned native Sayanox anchor, then its actual
source is compiled through fresh generations with gen3.c == gen4.c. This is
self-hosting with an explicit binary/host trust boundary, not diverse bootstrap
proof. C-output compatibility remains; C11 cc, POSIX process tools, coreutils timeout and digest
verification are host dependencies, not replacement implementations of gates.

Full acceptance requires every clause gate, all Sayanox suite families,
mandatory gen2/gen3 O0/O2 execution evidence, the complete builtin signature
matrix, runtime boundaries, integrity checks and negative controls. Missing
cases/IDs/generations, changed oracles and refused valid programs must fail.
Minimum bootstrap/fixed point, guarded CI, 64 MiB budget and cold recovery
remain mandatory and separately visible. Final local/remote results must be
recorded against the exact source checkpoint; older green jobs do not qualify.
Future richer types/modules, ARM/RV completeness, a full stdlib and independent
trust proof are not added to this agreed scope.
