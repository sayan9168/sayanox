# Published-language v1 implementation review

Reviewed against SYNTAX.md, TYPES.md, GENERICS.md, BUILTINS.md, MODULES.md and
current implemented increments on 2026-10-29. This is an implementation audit,
**not independent human certification or a record that execution passed**.
See STATUS.md for actual final-source evidence.

The pre-existing `test-gen2-list-args` case `sx_index([8,9],1)` also
retains its list overload; the builtin table's string example is not a
string-only restriction. The matrix checks both members of every union kind.

## Census

| Clause group | Forms retained and evidence families |
|---|---|
| LEX-01/02 | Line comments, escaped string delimiters, quoted braces/dots, malformed literal/grouping; condition and for-header fixtures plus lexer refusals |
| NUM-01 / TYPE-01 | Doubles, decimal fractions, unary/grouped arithmetic, precedence, modulo zero, declared num/str/list/nominal identity, assignment and signature refusals |
| SCOPE-01 / FN-01 | Source-ordered names, forward/mutual calls, no capture, typed/untyped headers, parameter reassignment, local expiry, structural return paths and concrete struct signatures |
| FLOW-01 / FOR-01 | Condition chains/else-if, while, word logic and numeric results, short-circuit effects, break/continue, named/live versus expression/once iteration, range/list/string sources inside/outside functions |
| LIST-01 | Numeric literal/growth/aliases, index get/set, list parameters/returns, checked postfix, recursive inline arguments and element evaluation order |
| STRUCT-01 | Nominal layouts, nested structs, expression fields, concrete list fields, documented dotted-initializer/whole-list and generic-signature exclusions |
| GENERIC-01 | Function specialization/inference/scope/queues, nested and list generic structs, first literal, depth/arity/inference/type-name boundaries |
| STRING-01/02 | Byte/C-string model, concat, content comparison in condition and scalar-value contexts, interpolation/import/escaping/GC/16-hole boundary, malformed/type-invalid holes |
| EXPR-01/02 | Zero-argument and grouped numeric calls, nested supported calls, every public builtin's argument kind/arity and valid counterpart, incompatible string/number operators |
| IMPORT-01 | Textual direct/nested splicing, eight/ninth depth, cycle, missing/unquoted paths, flat imported names; no new resolver/namespace promise |
| BUILTIN-01 / GC-01 | All 43 canonical calls, file/binary/stream/process/environment/status/bit/HTTP behavior, aliases/roots/retention and collection counters |
| HOST-01 | Pure-min own-source bootstrap, native trust input, fresh fixed point, checksum/recovery integrity, 64 MiB budget, original and full CI |

The two TSV inventories provide precise executable/source anchors. The full
runner executes their entire target union, not just the small closure suite.
The signature matrix's valid counterpart is required before its invalid cases;
accepting no programs cannot satisfy it. Negative controls separately test the
inventory, execution ledger and pinning rather than trusting summary messages.

## Resolved ambiguities without deleting published forms

1. Dated seed/native support tables describe backend increments, not a reason
   to remove later documented C-output forms. The compiler implementation's
   pure-min subset does not bound accepted user syntax.
2. Later nested/list generic implementations supersede the earlier scalar-only
   record. Explicit current initializer and signature context limits remain.
3. `sx_index` is the public string-byte call. `index` appeared only in an early
   draft inventory, not the published API, and was removed rather than invented.
4. `concat(s, n)` is explicitly documented and must format its second numeric
   argument. Its signature uses `v` (str-or-num). This does not legalize mixed
   string/number `+`; separate invalid contexts and valid counterparts cover it.
5. String call comparisons must compare contents, not C addresses. Coverage
   includes all six relations, reversed/call/call/grouped/concatenated operands,
   recursion, scalar hold/show/give/argument/field contexts and side-effect counts.
   This includes annotated bindings and field/element stores. Already checked
   scalar C is not reparsed as source (its hidden list temporaries are not
   source bindings); nominal checking still verifies the recorded return kind.
6. Inline list temporaries may have hoisted declarations, **never hoisted
   evaluation**. Function temporaries remain automatic to preserve recursion;
   short-circuit and repeated loop evaluation remain observable.
7. Published flat-main bindings must survive generated C blocks. Nested main
   declarations are hoisted without initializers or hidden loop indices;
   function-local lexical lifetime is not broadened. The process fixture reuses
   a binder introduced in a previous loop rather than renaming away the bug.
8. Invalid process handles cannot truncate a fractional ID onto a live slot.
   Process pipe descriptors must be close-on-exec so multiple live children can
   reach EOF independently. Partial pipe setup and interrupted waits are handled.
9. Bit operands and shifts are range-checked before integer conversion. The
   representable 2^64 endpoint retains rounded-mask compatibility; in-range
   fractions retain documented truncation rather than imposing a new integer-only
   syntax restriction. NaN/infinity/out-of-range boundaries are exercised.
10. `write_bytes` explicitly returns 0 on invalid input. Validation precedes
    opening/truncating an existing destination; this specific status rule wins
    over old collective 'hard error' wording. `read_bytes` commits appended bytes
    only after successful read/close, preserving its documented failure rule.
11. HTTP keeps its exact decimal 1,000,000-byte cap, rate, method, scheme and URL
    policy. Failed transport cannot return partial stdout; oversize data cannot
    look successful. The native Sayanox stand-in emits exactly 1,000,001 bytes
    or a partial body followed by exit 7, and an invocation marker prevents a
    missing transport from accidentally satisfying empty-body expectations.
12. Minimum/frozen-seed behavior is not retroactively called complete. The
    versioned full C-output profile, original acceptance, guarded execution,
    budget/recovery and remote checks remain distinct recorded obligations.

## Review limits

A finite regression suite is not a mathematical proof for every input. The
census closes the currently published forms and explicit boundaries, not future
syntax or a universal expression grammar in legacy contexts. A newly discovered
counterexample to a promised form must fail acceptance and gain a positive and
invalid/boundary regression; it must not be hidden by changing an oracle or
narrowing this profile. No precise/bounded GC, independent bootstrap trust,
complete native ARM/RV backend, expanded stdlib, namespaced module system or
Linguist registration is claimed by this review.
