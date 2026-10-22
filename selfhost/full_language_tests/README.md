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
`make test-generic-structs-nested` instead; nothing in this suite probes
them.

Even all four passing would not prove exhaustive language coverage. A reviewed,
versioned complete language acceptance specification is still required before
any full-language claim. `true-selfhost-full` now fails closed rather than
returning success for the subset under a misleading target name.

2026-10-17 update: the concrete struct-function probe now passes on gen2 and
gen3. `make test-struct-functions` separately pins its nominal type checks,
bounded refusals and GC retention; seed/native signatures are not included.
After that pass three readiness behaviors still failed (six checks).

Current update: identifier string interpolation also passes on gen2/gen3.
`make test-string-interpolation` pins its string/number, escaping, import, GC
and diagnostic bounds. Expression-valued fields and numeric index calls still
fail: **four checks across two compilers**. Seed/native interpolation is not added.
