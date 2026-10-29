# Full-language self-host contract — agreed scope, draft acceptance

2026-10-28. **Scope A agreed by the user; normative contract/coverage still
DRAFT, no full-language completion claim.**

The repository has a pure-min syntax reference, a broader feature reference,
backend-specific limitations and future type-system proposals. They are not one
reviewed normative language specification. Treating a passing subset as that
specification would silently change the user's request.

## Agreed scope A: the currently published broad language

Close the published language's actual divergences before claiming conformance.
Keep the own-source compiler in the pure-min bootstrap intersection; source
style does not determine the language accepted by the compiled compiler.

| Contract area | Required acceptance coverage |
|---|---|
| Lexing | comments, string escapes, quotes, delimiters inside literals, malformed token diagnostics |
| Values/operators | numeric semantics, precedence, comparisons, logical short circuit, string content comparison and numeric/string type errors |
| Bindings/scopes | declaration, assignment, shadowing, function/loop scope, name resolution and use-before-declaration refusals |
| Control flow | every published conditional spelling, while, each documented for-source form, nesting and malformed bodies |
| Functions | documented typed/untyped forms, calls/arity, forward/mutual recursion, parameters, returns, return-path checks and supported struct signatures |
| Lists | declared element model, literals, indexing/assignment, growth, aliases, calls/returns, bounds and GC retention |
| Structs | nominal identity, literals, nested fields, list fields, field expressions and documented annotations; resolve backend divergences explicitly |
| Generics | every published type argument/instantiation form, inference rules, nested layouts, lexical scope, type/arity errors and documented bounds |
| Strings | indexing, concat, escaping, interpolation, its documented limits, imports and retention under collection |
| Imports | textual use semantics, search/depth/cycle/duplicate rules and diagnostics; not silently promote sxmod to language namespaces |
| Builtins/runtime | complete BUILTINS inventory with argument/result/error semantics, IO/process/resource failures and memory safety under GC |
| Toolchain | pinned native bootstrap, own-source generations, gen3 == gen4, strict C-output builds, supported native parity, recovery and guarded CI |

A complete contract needs stable clause IDs, normative grammar/semantics and
per-clause positive, negative, boundary and cross-generation coverage. Existing
gates are evidence inputs, not automatic proof that every row is closed.
Known implementation limits must not disappear from the contract just to pass.

## Scope B was not selected: future language proposals

Also specify which TYPES_ROADMAP / language-level module or other proposed
features are required in version 1. Those are new language design decisions,
not merely a self-host gate rename. They need an explicit feature inventory
before implementation and acceptance can be judged complete.

## Work started, not closure

* Quote/escape-aware condition scanning; outside-literal line comments act as
  whitespace. The original compiler emits invalid C for the new fixture.
* Quote/escape-aware for-source scanning: `{` and `..` inside string data are
  not body/range delimiters. The original compiler also fails this fixture.
* Ten readiness behaviors at O0/O2 across gen2/gen3; native parity includes
  the two common new literal/for cases (15 positives / 23 refusals).
* Checked grouped numeric calls now include byte/bitwise, file, process and
  command-status builtins, not just the zero-argument calls. Eleven wrong-arity
  or argument-kind cases per compiler are checked at O0/O2.
* A 42-line builtin/runtime oracle exercises file/byte/bitwise/argument and GC
  behavior, with invalid-scheme HTTP returning before any network invocation.

The native_aot subset still refuses outside-literal header comments; that case
is tested on the C-output compiler, not hidden by the common native fixture.
The final broader-numeric-source guarded regression chain exited 0: CI,
fresh fixed point, 64 MiB budget, recovery, 40 positive readiness executions,
44 refused C builds and guard-check. This is not whole-language acceptance;
STRING-002 and SPEC/COVER/HOST closure remain open.

The [v1 clause candidate](FULL_LANGUAGE_CONTRACT_V1.md) gives stable review
units for normalization and coverage. It is not yet a completion certificate.

## Concrete remaining acceptance gaps

| ID | Evidence / required next work | State |
|---|---|---|
| EXPR-001 | Zero-argument numeric builtin grouping is implemented with checked signatures and positive/arity tests; fresh local guarded regression passed | IMPLEMENTED, LOCAL REGRESSION PASS |
| EXPR-002 | Numeric builtin grouping implemented with signature checks; former bit_and witness promoted to readiness, and the 42-line surface fixture now uses grouped calls. Fresh local guarded regression passed | IMPLEMENTED, LOCAL REGRESSION PASS |
| STRING-002 | String-returning call compared with a literal still compares C addresses: preserved intended positive prints `0/1`, oracle requires `1/1`. An isolated typed-parser prototype self-compiles and matches a 46-line matrix at O0/O2, but is not integrated or accepted | OPEN |
| SPEC-001 | Normalize current rules from SYNTAX, TYPES, GENERICS, BUILTINS and current backend records; older Stage-2/C-seed descriptions are not normative current behavior | OPEN |
| COVER-001 | Complete positive/negative/boundary coverage for every normative clause and the complete builtin inventory; the ten probes are insufficient | OPEN |
| HOST-001 | Full own-source/fixed-point and guarded acceptance for the reviewed complete contract, including negative controls against missing coverage | OPEN |

`true-selfhost-full` intentionally remains fail-closed. Scope approval is not
approval of implementation completeness or the final acceptance evidence.
