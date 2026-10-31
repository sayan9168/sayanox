# Multi-ISA Sayanox compiler: current boundary

`tools/native32.sa` is a pure-Sayanox source compiler that emits Linux ELF for:

- i386 / ELF32 (`EM_386`),
- AArch64 / ELF64 (`EM_AARCH64`), and
- RV64IM / ELF64 (`EM_RISCV`).

The backend emits instructions and ELF containers directly: no assembler, linker,
or C compiler is used to create a target image. The AArch64/RV64 images are
executed by the pure-Sayanox user-mode emulator `tools/sxisaexec.sa` on the
x86-64 test host. RV64GC as a whole is **not** implemented or claimed.

```sh
./sx target native32 sxisaexec
./tools/native32 selfhost/native32_tests/strings.sa /tmp/strings.rv64 riscv64
./tools/sxisaexec --arch riscv64 --out /tmp/strings.out /tmp/strings.rv64
```

## Implemented compiler subset

- 32-bit integer expressions: `+ - * %`, comparisons, parentheses, unary minus,
  decimal integer constants, global names, and `len(STRING_NAME)` to obtain a
  string variable's current byte length (including after runtime reassignment).
  `len("literal")` also works in integer expressions, conditions and indices: it
  folds the decoded byte length without allocating a target string or using the
  concat heap. Empty literals, raw UTF-8 bytes, and `\n`, `\t`, `\"` and
  `\\` escapes are supported. Interpolation, numeric/hex/Unicode escapes, NUL
  and arbitrary expressions inside `len()` are refused in this subset. Variable
  lengths are still loaded at runtime, not folded from their initial value.
  **Known divergence (R13, found 2026-10-31):** `\r` is decoded by seed-min,
  gen2 and the published C-output contract (`"a\rb"` prints `a`, CR, `b`) but
  the native backend keeps the length while emitting the bytes `arb`. It is
  recorded as an open defect rather than silently dropped from this list;
  fixture code that needs CR builds it with `chr(13)` until the decoder is
  fixed or `\r` is refused at parse time.
- `hold` declarations and same-type assignment for numeric and static-string
  variables. Numeric globals occupy one 32-bit slot.
- Static string values backed by bytes in the image data segment. A string
  global stores a 32-bit pointer and the raw 32-bit string byte length. Literal
  reassignment updates both at runtime; `show` writes that span plus its
  newline. `len(STRING_NAME)` returns the raw byte length without the
  display newline. This permits different string lengths on distinct
  control-flow paths without a compile-time length assumption.
- `STRING_NAME[INDEX_EXPR]` reads one raw byte as an integer. Indices are
  zero-based; negative indices count back from the end, matching the language
  runtime. An out-of-range index exits with status 1. The index expression can
  use the numeric operators supported by this subset.
- `concat(STRING_ARG, STRING_ARG)` in a string declaration or assignment, where
  each argument is either a previously declared string variable or a quoted
  string literal. Variables contribute their current runtime byte spans;
  literals are decoded into the image's static data segment. Each execution
  copies both spans into a bounded 60 KiB bump heap, writes a newline and NUL
  terminator after the bytes, then updates the destination's pointer and raw
  length. `len()` excludes the display newline. The heap is private to each
  generated image and is not reclaimed; exhaustion exits the generated program
  with status 1. This remains narrower than general dynamic string support:
  nested/arbitrary string expressions are not concat operands, and
  embedded-NUL literals remain refused because the existing backends disagree
  on their output semantics.
- `when`, `otherwise`, `while`, comments, and blank lines.

Lists, structs, user functions, floating-point expressions, general file APIs,
and garbage collection remain unsupported by this compiler. Other general
string operations such as `chr` and `string_eq` are also not in this subset.
Cross-type assignment and using a string as a numeric value are rejected. `/`
and fractional literals are rejected because Sayanox numbers are doubles and
this compiler does not yet implement floating-point expression semantics.

## Verification

`./sx target test-native32`, `./sx target test-native-arm64`, and
`./sx target test-native-riscv64` check image formats, deterministic output, data
layout and the documented refusal boundary. `./sx target test-sxisaexec` runs the
AArch64 and RV64 output, and includes a six-way parity fixture for static string declaration,
reassignment, positive and negative string indexing (including arithmetic
indices and indexed concatenation results), `concat` allocation and
reassignment, branch- and loop-dependent lengths, `len()` results, integer
output, and literal output. The gate also checks out-of-range indexing and
bounded-heap exhaustion on all runnable targets, retains integer parity, and
exercises emulator safety negatives plus scalar FP and Linux syscall probes.
The latter are emulator tests, not native compiler features.

The additional `len_literals.sa` fixture has an independent tracked byte-output
oracle and runs through the same multi-backend execution comparisons. Each ISA
gate also checks deterministic images and 16 malformed/type/unsupported literal
refusals (48 across the three targets). Existing reviewed golden images and
refusal matrices remain unchanged. See STATUS for this increment's acceptance.

The string fixture compares seed-min, gen2, x86-64 native AOT, the Portable IR
VM when available, i386 when the host kernel supports it, AArch64 under
`sxisaexec`, and RV64 under `sxisaexec`. It is end-to-end evidence for this
compiler slice, not a claim of complete language or ABI coverage.

## Target and runtime limits

- Integer values are 32-bit two's complement. Keep computed arithmetic in
  range; overflow behavior differs from double-based backends.
- Numeric and string globals are stored in the writable data segment, addressed
  using the backend's fixed image layout. String pointers fit in the low 4 GiB
  because both ELF64 targets use the fixed `0x400000` base.
- The generated code must fit in the first mapped page (the backend diagnoses
  overflow). Static strings and globals enlarge the data segment.
- The emulator supports only the exercised instruction subsets. It currently
  executes the native32 integer/string images, scalar IEEE-754 F/D arithmetic
  probes, and bounded Linux `openat`/`read`/`write`/`close`/`exit` calls. The
  file descriptor model is intentionally bounded and is not a native compiler
  file-I/O runtime.
- `tools/sxisaexec.sa` is written in Sayanox and enforces ELF, memory,
  alignment, instruction, syscall, and step-budget checks. See its source and
  `tools/sxisaexec_test.sa` for the exact emulator boundary.

## Roadmap status

This work is an incremental step toward full AArch64 and RV64GC native compiler
and runtime support. Bounded `concat` and byte indexing extend the original
integer/static-string backend, but do not complete that roadmap item. General
string operations beyond the documented subset, lists, structs and functions,
IEEE-754 code generation, native file I/O, and a mark-and-sweep collector
remain open, along with broader ISA support and end-to-end parity for each. Do not count
emulator-only FP/syscall probes as compiler support.

The legacy seed/gen2 reference grammar does not accept a spaced `len (` call or
`len("literal")` directly inside an index. The six-way harness uses
`len_literals_common.sa` (ordinary call spacing and a held numeric index) for
that shared grammar, then separately executes the original native-only forms
on ARM64/RV64 and on i386 when the kernel supports IA32. Both compare with the
same independent `len_literals.want`; these native cases are not discarded or
claimed as new legacy frontend support.
