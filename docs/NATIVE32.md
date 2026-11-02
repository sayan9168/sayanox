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
  declared string variable, a quoted literal or a whole `chr(X)` value. It is a numeric expression that
  yields `1` or `0`, so it can drive `when` and `while` conditions, feed `show`,
  and compose with the numeric operators (`string_eq(a, b) == 1`,
  `string_eq(a, b) == string_eq(c, d)`). The emitter pushes the two
  `(pointer, length)` pairs and calls one comparison routine emitted once per
  image: it rejects different lengths first, then compares bytes. Literal
  arguments are appended to the data segment and addressed through the per-arch
  load base, so the data image stays arch-neutral; nothing is allocated, so
  equality cannot consume the concat heap.
- **`chr(X)`** (2026-11-01): a one-byte string from a numeric code, accepted
  exactly where a whole string value is expected — `hold s = chr(X)`,
  `s = chr(X)` and `show chr(X)` — with `X` an integer literal or a declared
  numeric variable. The low byte is kept (`chr(300)` is byte 44, `chr(-1)`
  through a variable is byte 255), which is what the C backend's
  `(char)(long)v` does, and `chr(0)` is empty text with length 0, as the
  published runtimes define it. Each source occurrence owns a 4-byte cell in the
  data segment: the byte is written with a one-byte store, the following byte
  stays a newline (the invariant `show` relies on for every string in this
  backend), and the stored pointer is `cell + 1 - length`, so an empty `chr`
  points at that newline and prints exactly one line break. Sites never share a
  cell, so two live `chr` results are independent; nothing is allocated, so
  `chr` cannot consume the concat heap, and the cells are zero-filled in the
  image, which keeps the data segment arch-neutral.
- **Nested `chr`** (2026-11-02): `chr(X)` is now a first-class value inside the
  three calls that take string arguments, so `concat(chr(65), "x")`,
  `concat("x", chr(65))`, `concat(chr(65), chr(66))`, `string_eq(chr(65), "A")`,
  `string_eq("A", chr(65))`, `string_eq(chr(65), chr(66))` and `len(chr(65))`
  all compile. No new push form was added: the backend materialises each
  argument into a hidden `(pointer, length)` slot in the data segment with the
  same cell/`udiv`/`cell + 1 - length` sequence the whole-value form uses, then
  feeds that slot to the existing `concat`/`string_eq` push paths, so the
  argument is a plain pair by the time those paths run. Every address is an
  absolute immediate (the data base is fixed per target), so no fixup is
  involved and nothing is allocated. `emit_chr_value` takes five parameters
  because the published language allows at most six per `make` — the per-site
  values travel in a `chr_spec(kind, value, src)` list, and `test-native-sxdefs`
  (which compiles this emitter with `native_aot`) is what enforces the limit. The argument inside `chr(...)` is still
  one integer literal or one declared numeric variable: `chr(n + 1)`,
  `chr("A")`, `chr(nope)` and a numeric variable are refused in the nested
  positions exactly as they are in the whole-value positions, and a `chr`
  argument is not accepted anywhere else (it is not a general string
  expression).
- `when`, `otherwise`, `while`, comments, and blank lines.

Lists, structs, user functions, floating-point expressions, general file APIs,
and garbage collection remain unsupported by this compiler. `chr` is accepted as
a whole string value and as one whole argument of `concat`, `string_eq` and
`len`, and nowhere else: an argument that is more than an integer literal or a
numeric variable (`chr(n + 1)`, a signed literal such as `chr(-1)`, `chr("A")`,
`chr(nope)`) is refused in both positions, and `string_eq` arguments remain a
variable, a literal or a `chr(...)` value rather than arbitrary string
expressions, so `concat(chr(65), concat("a", "b"))` is still refused. Holding
the value first (`hold c = chr(65)`) remains the way to use it anywhere else.
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

The `chr.sa` fixture covers `chr` on the same six execution paths and in the
same cross-ISA data comparison: literal and variable codes, an out-of-range code
(300 becomes byte 44), a negative code built through a variable (byte 255),
`chr(0)` as empty text, assignment into an existing string variable, `len`,
byte indexing, copy and `string_eq` of a `chr` value, two live results that must
not share a cell, and a `chr` built inside a loop. The independent oracle is the
agreement between the seed-min, gen2, x86-64 native AOT, i386, AArch64 and RV64
outputs, not the emitter's own expectation.

The `chr_nested.sa` fixture covers the nested forms on the same six execution
paths: `chr` on the left, on the right and on both sides of `concat`, `chr` of a
variable, an empty `chr(0)` as a `concat` operand, `string_eq` with a `chr`
argument on either side and with two `chr` arguments, `len(chr(...))`, and the
`len`/index of a `concat` result built from `chr`. Its data segment is *not*
compared byte-for-byte across the three ISA images: a `concat` literal stores
its pointer (data base + offset) in the data segment at layout time, so only the
layout is cross-ISA identical until that becomes a runtime value (R14). The
gate therefore pins the data-segment *size* (297 bytes) on each target and
relies on the reviewed per-arch goldens plus six-way execution parity for the
bytes that matter. The refusal matrix rises from 26 to 31: `concat(chr(65, 66),
"x")` (wrong `chr` arity), `chr("A")` and `chr(nope)` as `string_eq`/`concat`
arguments, `chr(n + 1)` as a `concat` argument, `string_eq(chr(65), n)` with a
numeric second argument, and `len(chr(t))` with a string argument. The old
`concat_call` refusal (`concat(text, chr(121))`) is gone because that program is
now accepted by this backend - the `chr_nested` fixture is its replacement.

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
- **Image layout (2026-11-01, second code page).** i386 maps two text pages at
  `0x08048000` with the writable data segment at `0x0804A000`; AArch64/RV64IM map
  two text pages at `0x400000` with data at `0x402000`. Generated code may use up
  to `8192 - 116` bytes on i386 and `8192 - 176` on the 64-bit targets (the
  backend diagnoses overflow), because the previous one-page ceiling was
  completely consumed (the `streq` image ended exactly at `4096 - 116`). Static
  strings and globals enlarge the data segment. `tools/sxisaexec.sa` therefore
  maps `0x400000..0x424000` (36 pages) so the 60 KiB concat heap still fits above
  the moved data segment.
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
string operations beyond the documented subset (nested `chr` is now lowered),
lists, structs and functions,
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
