# Generic struct bootstrap limit — 2026-10-16

Actual stdout/stderr from `make test-generic-structs test-type-refusals`, then
`make doctor`, `make true-selfhost`, `make gen3`, `make native-test`, in order.
Each completed successfully; gen3/gen4 were byte-identical. No compiler/runtime
implementation changed in this increment. No interpreter was added or used.

The new matrix checks seven bad requests after valid scalar specializations.
Gen2's `#error` is also checked by a failing C compilation. Targeted type errors
are not claimed for every backend/spelling: Gen2 can say `undefined name: Box`;
native's line-comment-separated argument can say invalid type argument.

Development probes initially expected a more specific error for the
comment-separated case. Block-comment syntax produced the seed's generic `id`
error, so the fixture uses supported line-comment syntax. The final assertion
accepts native's explicit type-argument diagnostic for that spelling. Final
logs here are from the subsequent successful run, not those development probes.
