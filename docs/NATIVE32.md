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
- `concat(STRING_ARG, STRING_ARG)` in a string declaration, an assignment or a
  `show`, where each argument is a previously declared string variable, a
  quoted string literal, a whole `chr(X)` value or another `concat(...)` call. Variables contribute their current runtime byte spans;
  literals are decoded into the image's static data segment. Each execution
  copies both spans into a bounded 60 KiB bump heap, writes a newline and NUL
  terminator after the bytes, then updates the destination's pointer and raw
  length. `len()` excludes the display newline. The heap is private to each
  generated image and is not reclaimed; exhaustion exits the generated program
  with status 1. This remains narrower than general dynamic string support:
  `concat` is a statement-level form (it is refused inside any other expression,
  including as a `string_eq` argument), and embedded-NUL literals remain refused
  because the existing backends disagree on their output semantics.
- **General string expressions** (2026-11-02): `show concat(A, B)` prints a
  concatenation without naming a variable, and a `concat` operand may itself be
  a `concat(...)` call, so `concat(concat(a, "-"), b)`,
  `concat("pre-", concat(a, "!"))` and
  `concat(concat("1", "2"), concat("3", "4"))` all lower. A nested call is
  emitted first into a hidden `(pointer, length)` slot in the data segment; that
  slot then stands in for the operand, so the emitter keeps one copy routine
  whatever the mixture of variables, literals, `chr(...)` values and nested
  calls. Nesting is limited to seven levels (one hidden pair slot per level);
  deeper nesting, a numeric operand, a numeric variable operand and a
  one-argument call are all refused with a line-numbered diagnostic. The
  `concat_expr` fixture exercises all of these forms on the six execution paths
  with reviewed AArch64/RV64IM goldens.
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
  `s = chr(X)` and `show chr(X)` — with `X` an integer literal, a declared
  numeric variable, or (since 2026-11-02) any integer expression this subset
  accepts: `chr(n + 1)`, `chr(len(s) + 62)`, `chr((n + 60) + 1)`. A literal or a
  bare name keeps the direct lowering; an expression is compiled first and its
  value parked in a shared 4-byte scratch word, then read back through the same
  numeric-slot path, so the per-occurrence byte cell keeps its
  `[byte][newline][0][0]` layout. Since 2026-11-02 the expression form works in
  **every** position `chr` is accepted in — as a `concat` operand
  (`concat(chr(n + 1), "x")`), as a `string_eq` argument
  (`string_eq(chr(n + 61), "A")`, `string_eq("A", chr(n + 61))`,
  `string_eq(chr(n + 61), chr(n + 62))`) and inside `len(chr(n + 61))`. That is
  possible because the integer expression emitter is one function: the calls
  whose arguments are scanned as tokens find the matching parenthesis, render
  the inner tokens back into text and compile them, which is the same path the
  statement-level form uses. The low byte is kept (`chr(300)` is byte 44, `chr(-1)`
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
- **Numeric user functions (2026-11-02):** `make NAME(a: num, b: num) -> num { … }`
  with up to 6 `num` parameters and one `num` result, called as a whole value
  (`hold x = f(1, 2)`, `x = f(…)`, `show f(…)`, a `when`/`while` condition, an
  argument of another call) and **as an operand of any integer expression**
  (`f(1) + 1`, `2 * f(3) - 1`, `f(1) * g(2)`, `add(inc(1) + 1, inc(2))`,
  `when f(1) + 1 == 3`). A body is lifted
  out of the program text, emitted after the main program behind a jump and
  reached with a real `call`, so `call`/`ret` are the only new control-transfer
  instructions per ISA (i386 `E8`/`C3`, AArch64 `BL`/`RET`, RV64IM
  `JAL`/`JALR x0,0(x1)`). `give` returns; it may also sit inside a `when` branch
  for an early return, and every body must end with a top-level `give`. Refused,
  each with its own diagnostic: a call to an undeclared name, wrong arity, a
  string argument, an untyped or non-`num` parameter, a non-`num` return type, a
  duplicate name, a body without a `give`, a body that does not end with one,
  more than 8 functions, more than 6 parameters, more than 60 words of locals in
  one frame, and `give` outside a body. `concat` is still a statement-level
  form, so a call result can feed a call, an operator or a condition but not a
  `concat` argument.
  **Since 2026-11-02 a body may also call another function**, and **since
  2026-11-07 every invocation owns its own frame**, so direct and mutual
  recursion are legal:
  * The caller evaluates the arguments left to right and pushes them on the
    value stack; they stay there across the call and the caller pops them after
    the return, so the result register is never clobbered. A callee reads
    argument *k* relative to its own frame base, never through a global slot.
  * The prologue saves the caller's frame base in the frame, records the new
    base in one data word, zero-fills the body's local words (so a local read
    before its first assignment sees zero on every invocation, as on the C
    backends) and bumps a shared depth word. The epilogue restores the stack
    pointer, the caller's frame base and the return address, then decrements
    depth.
  * Frame slots are addressed as `frame_base + disp` through that one data
    word, never through a dedicated register: the i386 `concat` copy sequence
    already uses every general register.
  * **Recursion is bounded, not unbounded:** a call that would open the 65th
    live frame jumps to a shared overflow stub that exits 1 without writing any
    output, the same contract as the other native32 runtime bounds. The cap is
    a depth counter, not a timer, and a refused program produces no partial
    output.
  * i386 uses `push`/`pop` on the same stack as `ret`; AArch64 and RV64IM save
    the link register and the caller's frame base in 16-byte slots below it,
    because `bl`/`jal` overwrite the link register. The RV64 prologue stores
    `ra` at displacement 0 of its slot and the epilogue reloads it: an earlier
    `sd ra,8(sp)` left the reloaded slot empty, which stayed invisible until one
    body called another (the nested `jal` clobbered `x1`, and the outer `ret`
    then jumped through the uninitialised word — `unmapped memory access at
    vaddr 0` in the emulator). The `fn` and `recursion` fixtures fail on that
    build and pass on the current one.
  **Since 2026-11-03 a call is also an operand.**
  The call is emitted where the token stands and its result is pushed like any
  other value, so `f(1) + 1`, `2 * f(3) - 1`, `f(1) * g(2)`, a call inside a
  call's argument expression and a call in a condition all lower; the value
  stack stays balanced because a call pops its own arguments before `call` and
  the callee's expression leaves one value in the accumulator.

Lists, structs, string-valued functions, floating-point expressions, general
file APIs, and garbage collection remain unsupported by this compiler; recursion
is supported but capped at 64 live frames, so an unbounded recurrence is a
runtime exit, not a compile-time guarantee. `chr` is accepted as
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
segment is compared across the three ISA images. Every fixture in the list now
has a byte-identical data segment on all three targets, `concat` programs
included: the arch-specific values such a program needs (literal argument
pointers and the heap bump pointer) are written at run time instead of being
baked into the image (R14, fixed 2026-11-02, see the
[remaining-work register](REMAINING_WORK.md)).

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
`len`/index of a `concat` result built from `chr`. It is the first accepted
`concat` program, so it is also the fixture that proves the *data segment* is
byte-identical across i386, AArch64 and RV64IM for a program with `concat`
(R14, fixed 2026-11-02). Nested `chr` raised the refusal matrix from 26 to 31:
`concat(chr(65, 66), "x")` (wrong `chr` arity), `chr("A")` and `chr(nope)` as
`string_eq`/`concat` arguments, `chr(n + 1)` as a `concat` argument,
`string_eq(chr(65), n)` with a numeric second argument, and `len(chr(t))` with a
string argument. The `concat_expr` increment raised it further to 36: a numeric
variable as a `concat` operand, a numeric literal operand, a one-argument
`concat`, eight-level nesting, and `concat(...)` used inside `string_eq`. The
`chr`-of-expression increment took the matrix to 39: `refuse/chr_expression.sa`
(`chr(n + 1)`) was deleted because that program is now accepted, and four
refusals were added — a string variable in the `chr` expression, an unknown
name, a two-argument `chr(n, 1)`, and `string_eq(chr(n + 1), "A")`. The
argument-position increment moved it to 40: `refuse/chr_nested_expression.sa`
and `refuse/chr_expr_streq.sa` were deleted because those programs are accepted
now, and three refusals were added — a string variable, an unknown name and a
division inside the `chr` argument of `concat`, `len` and `string_eq`. The old
`concat_call` refusal (`concat(text, chr(121))`) is gone because that program is
now accepted by this backend - the `chr_nested` fixture is its replacement.

The `fn.sa` fixture is the numeric-function contract: whole-value and operand
calls, a body calling another body, a three-level chain and a call inside a
condition, run through seed-min, gen2, x86-64 native AOT, i386, AArch64 and
RV64IM. `recursion.sa` is the step-11 contract: `fact`, `fib`, mutual
`even`/`odd`, a recursive accumulator whose per-depth locals would collapse if a
frame were shared, a recursive body that reassigns its parameter, and recursion
inside an operand and a condition — identical output on all six execution paths,
with reviewed AArch64/RV64IM goldens. `fn_depth_cap.sa` is the negative control
for the cap: `give down(n + 1)` runs until the 65th live frame and exits 1 with
an empty output file on i386, AArch64 and RV64IM. Both goldens are pinned by
byte equality, so the old RV64 prologue (`sd ra,8(sp)` with no `ld ra`) fails
`test-sxisaexec` on `fn` instead of passing silently.

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
- **Recursion and stack budget.** Every live `make` invocation costs its own
  frame: the caller-pushed arguments (4 bytes each on i386, 16 on AArch64 and
  RV64IM), the saved linkage (4 bytes of caller base on i386, 32 on the 64-bit
  targets) and at most 60 words of locals. At most 64 frames can be live, so a
  recursive program's stack use is bounded by construction and the 65th call is
  a clean exit 1, not a stack overflow.
- Numeric and string globals are stored in the writable data segment, addressed
  using the backend's fixed image layout. String pointers fit in the low 4 GiB
  because both ELF64 targets use the fixed `0x400000` base.
- **Image layout (2026-11-01, second code page).** i386 maps two text pages at
  `0x08048000` with the writable data segment at `0x0804A000`; AArch64/RV64IM map
  two text pages at `0x400000` with data at `0x402000`. Generated code may use up
  to `8192 - 116` bytes on i386 and `8192 - 176` on the 64-bit targets (the
  backend diagnoses overflow), because the previous one-page ceiling was
  completely consumed (the `streq` image ended exactly at `4096 - 116`). Static
  strings and globals enlarge the data segment. Data offsets `0..31` are the
  decimal print buffer and `32..35` hold the `concat` bump pointer, which the
  entry code initialises from the target's own data base, so no data address is
  baked into the image. `tools/sxisaexec.sa` therefore maps
  `0x400000..0x424000` (36 pages) so the 60 KiB concat heap still fits above the
  moved data segment.
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
string operations beyond the documented subset (nested `chr`, `show concat(...)`
and nested `concat` operands are now lowered; `concat` inside other expressions
is not), lists, structs and functions,
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
