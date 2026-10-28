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
