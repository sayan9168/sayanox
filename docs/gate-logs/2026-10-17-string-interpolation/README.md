# 2026-10-17 — bounded identifier string interpolation

Actual ordered runs, all exit 0:

- `make pack-compiler`: main recovery and live module round trips.
- `make doctor`
- `make true-selfhost`
- `make gen3`: byte-identical gen3/gen4; source feature, struct-function and
  interpolation tests included.
- `make native-test`

Final expanded `make test-string-interpolation` also exited 0; see
`interpolation.log`. Both gen2/gen3 pass five positive fixtures at O0/O2,
the 16-hole limit and ten source-diagnostic refusals. Generated C is checked
in C11 mode. Extra fixtures cover escaped-only strings and coexistence with
struct-typed functions.

`make test-full-language-readiness` independently exited **2** with **four**
unmet checks. Identifier interpolation and named struct function probes pass;
expression-valued struct fields and numeric function calls in indexes still
fail on both compilers.

The implementation is in .sa, not an interpreter. Seed-min/native interpolation,
expression holes and format specifiers are not added. No full-language claim,
new collector in seed, or new memory-improvement measurement.
