# 2026-10-17 — bounded concrete struct function types

Actual ordered runs, all exit 0: `make doctor`, `make true-selfhost`,
`make gen3` (including struct-function tests), `make native-test`.
`make pack-compiler` also exited 0 (120 main recovery parts, module round-trip).
The final expanded `make test-struct-functions` exited 0 on gen2/gen3:
three output fixtures at O0/O2, plus 14 diagnostic/refusal cases per compiler.
`typed-and-list-regression.log`: actual `make test-typed-sig
test-gen2-list-struct-fields`, exit 0.

`make test-full-language-readiness` separately exited **2**, with six unmet
behavior checks. The named-struct function probe now passes on both compilers;
interpolation, expression fields and numeric index calls still fail.

No seed/native struct function ABI implementation, no full-language self-host
claim, no new RSS measurement. Detailed bounds are in FULL_LANGUAGE_SELFHOST.md.
