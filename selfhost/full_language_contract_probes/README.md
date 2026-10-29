# Open full-contract positive witnesses

These are intended **positive** programs for the agreed published whole-language
scope, not expected-refusal tests. They are not counted as passing readiness.
`true-selfhost-full` remains fail-closed while the complete contract is open.

`string_call_comparison.sa` must match its `.want` file (`1`, `1`). Fresh gen3 at O0/O2 instead prints `0`, `1`: a string-returning call is compared by C
pointer identity with a literal. The explicit string_eq companion demonstrates
that its string value is correct. A isolated typed-parser prototype is not an
accepted complete fix; compound expressions, escapes, effects, type errors and
self-host resource budgets need regression coverage before integration.

The former grouped bit_and witness is now in the regular readiness suite as
`../full_language_tests/grouped_numeric_builtin.sa`; it is no longer an open
witness after the checked numeric-call implementation (the latest 40 positive/44 negative readiness executions passed, but
whole-language acceptance is still incomplete).

`string_call_matrix.sa` extends the intended positives to 46 oracle lines:
six operators, both operand orders, fields, calls, string-add precedence,
parentheses/whitespace, numeric argument division, environment/file wrappers,
escaped data, loops, short circuit and exactly-once side effects. It is not
part of passing canonical readiness. Two isolated prototypes were examined:
a normalized-condition parser self-compiled and passed the initial 40-line
matrix; an original-condition parser with complete builtin alias lowering
self-compiled and passed all 46 lines at O0/O2. Neither is maintained compiler
source yet. In particular, inline-list temporaries need safe function/main
prologue declarations (including recursion and else-if chains), not unchecked
emitted identifiers or eager evaluation before a short-circuit condition.

The latest canonical numeric checkpoint was validated independently: guarded CI,
40 readiness executions, 44 refused C builds, the 64 MiB budget, cold recovery
and guard-check all passed. `./sx target true-selfhost-full` was also executed
to completion and exited 1 after its subset prerequisites passed, explicitly
refusing the missing reviewed exhaustive acceptance specification. No new
whole-language acceptance or remote acceptance is claimed.
