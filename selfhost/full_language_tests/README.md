# Broader-language readiness, not a completed full-language contract

These checked behavior probes expose concrete blockers rather than passing
because the compiler correctly refuses unsupported syntax. They run on actual
gen2/gen3, compile generated C with strict diagnostics and compare complete
stdout. A literal `${name}` output is not counted as string interpolation.

The probes are proposed closure requirements for the broad full-language goal:
string interpolation (formerly falsely claimed by a numeric interpolation
test), named-struct function parameter/return, expression-valued struct fields
and a checked numeric call as an index. They are NOT existing bootstrap-dialect
support promises. Failures are expected until implemented. Bootstrap
exclusions (module namespaces/aliases) are not silently reclassified as
implemented by this suite. Nested/list generic arguments were on that
exclusion list until 2026-10-22, when they were implemented and gated by
`./sx target test-generic-structs-nested` instead; nothing in this suite probes
them.

Even all four passing would not prove exhaustive language coverage. A reviewed,
versioned complete language acceptance specification is still required before
any full-language claim. `true-selfhost-full` now fails closed rather than
returning success for the subset under a misleading target name.

2026-10-17 update: the concrete struct-function probe now passes on gen2 and
gen3. `./sx target test-struct-functions` separately pins its nominal type checks,
bounded refusals and GC retention; seed/native signatures are not included.
After that pass three readiness behaviors still failed (six checks).

2026-10-22 update: expression-valued struct fields and numeric index calls
pass too, so **all eight checks (four behaviours on gen2 and gen3) pass** and
`./sx target gen3` runs this suite. `./sx target test-full-language-expr` pins both forms as
a three-backend parity fixture and pins what stays refused. Seed/native
interpolation is still not added, and passing four probes is still not a
full-language claim: `true-selfhost-full` fails closed for want of a
reviewed acceptance specification.

2026-10-28 current boundary: the dated seed/native exclusions above are not a
current native-backend limit. `./sx target test-native-stage2-parity` checks
native_aot against gen2 on **13 positive fixtures and 23 refusals**, including
all four readiness fixtures, interpolation and struct-function GC cases. This
was re-executed successfully with the seed metadata-compaction changes. The
own-source compiler still stays in the pure-min bootstrap intersection; these
probes do not supply the missing reviewed exhaustive full-language contract.

2026-10-28 closure work adds `condition_literals.sa`, `condition_comments.sa`,
`for_literals.sa`, `builtin_surface.sa`, `zeroarg_expressions.sa` and
`grouped_numeric_builtin.sa`. Readiness now has **ten behaviors
at O0/O2 on gen2/gen3 (40 stdout executions)**, while native parity has **15 positives
and 23 refusals**. It is still readiness, not exhaustive conformance.

The new cases cover quoted braces, escaped quotes/backslashes, comment-like
string data, control chains, typed function conditions, for-source strings
containing braces/range dots, and a 42-line file/byte/bitwise/argument/runtime
builtin oracle. Eleven wrong-arity or argument-kind numeric builtin calls must also emit
checked source diagnostics and fail C compilation at both O0/O2 on each
compiler (44 refused C builds). Invalid HTTP scheme testing never contacts a network.
`condition_comments.sa` is C-output-specific; native_aot still refuses header
comments, so only the common literal/for cases join native parity. Original
compiler negative controls fail the new syntax; the source-built fixes match
the stdout oracles. The earlier four/eight and thirteen counts above are
historical. Final-source local guarded regression, 64 MiB budget, recovery
and explicit gen3-required readiness all passed. These do not close the
known string-call comparison bug or the exhaustive contract. See the
[agreed scope draft](../../docs/FULL_LANGUAGE_CONTRACT_DRAFT.md).
