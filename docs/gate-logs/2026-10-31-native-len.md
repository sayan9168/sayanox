# Native literal len acceptance — 2026-10-31

## Reviewed increment

- Implementation: `95a91d1`; reference-grammar separation: `59c1109`.
- Accepted implementation/harness checkpoint:
  `59c11096b531850c823a5d21a034cfd01db7f5e6`.
- Fresh [GitHub run 41157427551](https://github.com/sayan9168/sayanox/actions/runs/41157427551):
  both **Sayanox entry and migrated acceptance gates** and **Complete original
  acceptance** succeeded, including both final forbidden-invocation audits.
  No guard, sanitizer, acceptance alias or cap was weakened.
- Documentation-update and post-merge checks are tracked in
  [PR #51](https://github.com/sayan9168/sayanox/pull/51), separately from that
  implementation run. They are not asserted complete by this record.

## Executed evidence

Local focused checks against the committed implementation:

- Three ISA executions match the tracked independent `len_literals.want`.
- 16 new refusal fixtures per ISA: **48/48** diagnostic refusals.
- Actual production decimal formatter: `0`, `1000000`, `2147483647` produce
  decimal-only tokens. These are development checks, not a new public CLI.
- Guarded official `test-native32`, `test-native-arm64`, `test-native-riscv64`,
  `test-sxisaexec` and `test-doc-claims`: **PASS**.
- Six-way shared fixture: seed+C, gen2+C, x86-64 native, Portable IR VM,
  AArch64 and RV64IM match byte-for-byte and match the independent oracle;
  the harness also checks i386 execution when the kernel supports IA32.
- Original native-only spaced-call and literal-index forms execute separately
  and match both the shared reference and the oracle. The local host ran i386;
  ARM64/RV64 execution remains mandatory regardless of host IA32 support.
- Existing reviewed images, refusal matrix, bounds/exhaustion probes, deep
  stress, syscall, scalar-FP and emulator negative controls remain unchanged
  and passed in the official parity target.
- Both checksum manifests and `git diff --check`: **PASS**.
- Local gen3/gen4 fixed-point outputs both SHA-256
  `33e2c9eb6eb0c33c18e5ad88386afb6861d979bcc7281397905c9cf2356d4903`.

The separate local full `./sx ci` repeat was still running when this record
was written; no final local exit status is asserted here. The completed remote
full-acceptance job above is the full-run acceptance evidence.

## Failure retained, not hidden

The first local six-way attempt failed because the legacy grammar rejects
`len (` spacing and a literal `len` directly in an index. Full CI did not run
after that failed focused attempt. The original native fixture was retained;
`len_literals_common.sa` provides an equivalent shared-grammar program (ordinary
spacing and a held index). Both are checked against one independent oracle.
No seed/compiler language scope was narrowed and no failing native case removed.

## Source identity and boundaries

Accepted implementation SHA-256:

- `tools/native32.sa`:
  `e0d84dc389f541d4a2adad1bf2455c108ee6577bde9af0cfa3bd3d6a33ca5321`
- `tools/sxisa_gates_lib.sa`:
  `f1692a118d3309366bc3ffd2214292189a2711c80f35338b1888a9c0c8253034`
- `tools/sxisaexec_test.sa`:
  `16a2f373fd1fc941e910d48b70f4cf63f94bbf59fbd06d0de58b4197c2866a03`

This is literal **byte** length, not Unicode character counting. The accepted
escapes are newline, tab, carriage return, double quote and backslash. NUL,
interpolation and unknown/numeric/hex/Unicode escape spellings are refused in
this new literal-folding path. Counts must fit the signed 32-bit positive range.
Variable lengths remain runtime loads. No new opcode template, runtime string
expression, floating-point backend or GC guarantee is claimed. Maintained
implementation/tests are Sayanox; generated C compatibility and necessary host
tools remain supported. Independent bootstrap remains **OPEN**.
