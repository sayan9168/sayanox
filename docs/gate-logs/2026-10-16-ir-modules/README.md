# Native IR audit and module-contract clarification — 2026-10-16

Actual combined stdout/stderr:

* `focused.log`: `make test-native-ir-portable test-use`
* `doctor.log`: `make doctor`
* `true-selfhost.log`: `make true-selfhost`
* `gen3.log`: `make gen3`
* `native-test.log`: `make native-test`

The four required gates ran in order as one `&&` chain, which exited zero.
Gen3/gen4 compared byte-identical. The native gate runs the streaming C99 tool
in default and strict/source-offset modes, compares deterministic output,
checks one offset comment per instruction, and compares the audit listing
minus those comments with the default listing. C/shell tests cover malformed,
backward, duplicate-offset and unknown-mnemonic cases. No interpreter is used.

No second executable ISA, cross-execution smoke test or executable IR was
added. Width collapse and x86 ABI/runtime assumptions are explicitly documented.
The module decision is documentation-only: no compiler/use expansion change,
no path-renaming aliases, and no new uniform alias-error claim. Existing
positive/nested use and missing/unquoted-path refusal tests passed.
