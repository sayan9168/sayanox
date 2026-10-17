# Self-host source expansion and failed full-language readiness — 2026-10-17

The full-language request is NOT completed. Actual required gate stdout/stderr
was captured from one ordered successful `&&` chain:

1. `make doctor`
2. `make true-selfhost`
3. `make gen3`
4. `make native-test`

The live compiler now imports a source module and actually uses its generic
minimum, as well as a generic source-size struct. The gen3 gate checks emitted
artifacts and runs the source module fixture through gen1-min/gen2/gen3, then
checks gen3/gen4 equality. Source and module recovery round-trips passed;
`module-recovery.log` was produced after temporarily deleting and restoring the
module, with a successful byte comparison to the saved source. Decoder tools
are still unnecessary when checked-in source is intact.

Separately, `make test-full-language-readiness` genuinely FAILED: eight checks
across gen2/gen3 are unmet. `readiness.log` records that failure, not a green
full-language gate. Representative compiler errors/output are retained here.
String interpolation emits literal text; struct function arguments/returns
become invalid C (not a precise language refusal); expression-valued fields and
call indexes are rejected through generated #error C.

The full-language target no longer succeeds by aliasing the subset. It now
fails closed pending readiness and a reviewed exhaustive acceptance contract.
The full target itself was not rerun as a duplicate full build in this pass;
its component subset/fixed-point gates and separate failing readiness target
were run as described above. Four probes are not an exhaustive specification.
Permanent bootstrap exclusions were not rebranded as supported features.

No interpreter/network dependency, new memory-reduction measurement or
full-language completion claim is made.
