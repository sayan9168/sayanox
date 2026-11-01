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
  **Fixed 2026-10-31 (R13):** the pure-min native decoder used to require
  full-language mode before mapping `\r` to CR, so `"a\rb"` kept its length
  while emitting the bytes `arb` and diverged from seed-min, gen2 and the
  published C-output contract. `tools/sxdata_lib.sa` now decodes `\r` in every
  mode, the pinned native anchor was rebuilt from source to the new fixed point
  (three-stage equality plus the DDC controls), and
  `selfhost/stdlib_text_test.sa` carries the `"a\rb"` / `"\r\t\r"` literals as
  the regression test on seed-min, gen2 and native AOT.
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
- **String-value copy** (2026-10-31): `hold b = a` and `b = a`, where `a` is an
  already-declared string variable, copy the 8-byte `(pointer, length)` pair
  through the accumulator. It is a value copy, not an alias: reassigning `a`
  afterwards leaves `b` at its old bytes, an empty string copies as length 0,
  and the copy allocates nothing, so it cannot consume the 60 KiB concat heap.
  Both variables must already be string variables - a numeric source into a
  string destination, or the reverse, is refused with "a variable cannot change
  between numeric and string values", and an undeclared source is refused as an
  unknown name. Arbitrary string expressions are still not sources: only a
  literal, `concat(...)`, or another string variable.
- **String equality** (2026-11-01): `string_eq(A, B)` where each argument is a
  declared string variable or a quoted literal. It is a numeric expression that
  yields `1` or `0`, so it can drive `when` and `while` conditions, feed `show`,
  and compose with the numeric operators (`string_eq(a, b) == 1`,
  `string_eq(a, b) == string_eq(c, d)`). The emitter pushes the two
  `(pointer, length)` pairs and calls one comparison routine emitted once per
  image: it rejects different lengths first, then compares bytes. Literal
  arguments are appended to the data segment and addressed through the per-arch
  load base, so the data image stays arch-neutral; nothing is allocated, so
  equality cannot consume the concat heap.
- `when`, `otherwise`, `while`, comments, and blank lines.

Lists, structs, user functions, floating-point expressions, general file APIs,
and garbage collection remain unsupported by this compiler. `chr` is still not
in this subset, so a one-byte string cannot be built from a number, and
`string_eq` arguments are limited to a variable or a literal rather than
arbitrary string expressions.
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

The `strcopy.sa` fixture covers the string-value copy on all six execution
paths (seed-min, gen2, x86-64 native AOT, i386, AArch64, RV64), and its data
segment is compared across the three ISA images. A known pre-existing limitation
found while adding it: a program that *uses* `concat` initialises its literal
temp slot in the data segment with an arch-specific absolute address, so that
program's data image is not cross-ISA identical even though each image is
correct for its own target. The copy fixture therefore avoids `concat`, and the
cross-ISA data assertion covers programs without `concat`. Recorded as R14 in
the [remaining-work register](REMAINING_WORK.md).

The `streq.sa` fixture covers `string_eq` on the same six execution paths and in
the same cross-ISA data comparison: literal/literal, variable/variable,
mixed, unequal lengths, a differing middle byte, empty strings, a copied value,
composition with `==`, a `when` branch, an equality test inside a loop body, and
one equality test as the loop condition itself. While adding it, a real defect
in the AArch64 emulator surfaced: the 64-bit Add/Subtract (immediate and shifted
register) forms computed their result but never updated `N`/`Z`/`C`/`V`, so a
64-bit `cmp` followed by `b.cond` branched on stale flags. `tools/sxisaexec.sa`
now sets those flags; the six-way `streq` run fails on the previous emulator and
passes on the fixed one, so the fix is pinned by the same fixture.

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
