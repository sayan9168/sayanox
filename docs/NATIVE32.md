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
./sx tool native32
./sx tool sxisaexec
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
  and arbitrary expressions inside `len()` are refused in this subset, except
  for the bounded `len(concat(...))` form described below. Variable
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
- `read_file(PATH)` and `write_file(PATH, TEXT)` reach the target's own Linux
  syscall ABI (`openat`, one `read` or `write`, `close`, `exit`), so a generated
  image needs no runtime. Both take a **string-literal** path only: the NUL that the
  syscall stops at has to be pooled with the literal, and a variable path is
  refused. `write_file`'s text must be a string, not a number. `read_file` performs
  one bounded read of 4096 bytes and returns the span up to the first NUL, so a
  file whose bytes contain a NUL reads back truncated and a file longer than 4096
  bytes reads back its first 4096; a path that cannot be opened gives the empty
  string, and `write_file` answers 0 for a failure rather than faulting. Each image
  carries at most one routine per builtin and one lazily reserved 4129-byte data
  block holding the arguments, the descriptor, the counts and the buffer, so a
  program that never names a builtin emits neither. See
  [the gate log](gate-logs/2026-11-23-arm64-isa-coverage.md).
- `concat(STRING_ARG, STRING_ARG)` in a string declaration, an assignment or a
  `show`, where each argument is a previously declared string variable, a
  quoted string literal, a whole `chr(X)` value or another `concat(...)` call. Variables contribute their current runtime byte spans;
  literals are decoded into the image's static data segment. Each execution
  copies both spans into a bounded 60 KiB bump heap, writes a newline and NUL
  terminator after the bytes, then updates the destination's pointer and raw
  length. `len()` excludes the display newline. The heap is private to each
  generated image and is not reclaimed; exhaustion exits the generated program
  with status 1. This remains narrower than general dynamic string support:
  `concat` is also accepted directly inside `len(concat(...))` in numeric
  expressions, using the same heap and operand limits. Calls to user functions
  inside those concat operands are refused to avoid clobbering shared scratch
  pairs during recursion. `string_eq` arguments are no longer limited to a
  variable, a literal or a `chr(...)` value: a whole `concat(...)` or a whole
  `-> str` call is accepted there too (see *String equality over string
  expressions* below). Remaining expression positions are still refused, and
  embedded-NUL literals remain refused because the existing backends disagree
  on their output semantics.
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
  with reviewed AArch64/RV64IM goldens. `concat_len` additionally exercises
  nested concat lengths, escaped literals and function-local strings on all six
  execution paths. Local slots use a negative frame displacement; string and
  `chr` lowering recognizes those slots rather than treating them as absolute
  data offsets.
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
- **String equality over string expressions** (2026-11-17): a `string_eq`
  argument is no longer just one token. The emitter finds the matching `)` of an
  argument that opens a multi-token string expression and accepts
  `concat(<operand>, <operand>)` and a `-> str` call in either position, in
  addition to the existing `chr(<expr>)` form, so
  `string_eq(concat(a, c), "alphabeta")`,
  `string_eq("alphabeta", concat(a, c))`,
  `string_eq(concat(a, c), concat("alpha", "beta"))`,
  `string_eq(concat(concat(a, "-"), c), "alpha-beta")`,
  `string_eq(concat(chr(65), "lpha"), "Alpha")` and
  `string_eq(wrap(a), "[alpha")` all compile and answer 0 or 1. A `concat`
  argument materializes its pair in the data segment (the same
  `(pointer, length)` push the `chr` path uses), so nested `concat`, `chr`
  operands and empty operands keep one argument shape, and a `-> str` call
  reuses its result pair. An argument that is a plain literal is pooled by the
  ordinal counted from the expression text, so a literal *after* an argument
  that carries literals of its own (`string_eq(concat(a, "x"), "abx")`) still
  indexes the right literal. The new `streq_expr` fixture covers these forms on
  the six execution paths (i386 8664 bytes, reviewed AArch64/RV64IM goldens,
  output compared against the x86-64 native AOT lane). The refusal matrix
  stays 64: `refuse/concat_streq_arg.sa` (a `concat` inside `string_eq`) became
  a legal program and was deleted, its form moved into `streq_expr`, and
  `refuse/streq_in_body.sa` was added.

  The same increment fixed a **silent miscompile**: a `string_eq` inside a
  `make` body emitted its argument pushes and left the call site unpatched — the
  shared comparison routine is placed after the main program, but the bodies are
  emitted after it and the call sites are patched when the routine is placed —
  so a body comparison printed the two operand lengths instead of 0 or 1. No
  fixture used that form, which is why the suite stayed green. Step 14 replaced
  that refusal with a correct link (see *String equality inside `make` bodies*
  below).

- **String equality inside `make` bodies** (2026-11-17, step 14): the body
  miscompile from step 13 is fixed by link order instead of a refusal. The
  shared comparison routine is placed exactly where it was (behind a jump after
  the main program), but its call sites are now patched *after* the `make`
  bodies are walked, and a program whose only comparisons are in bodies places
  the routine after the bodies, behind a jump over the exit sequence. So
  `show string_eq(x, "ab")` inside a body answers 0 or 1, as do body
  comparisons with `concat(...)`/`-> str` arguments, comparisons of a body
  local built by `concat`, comparisons in `when` and `while` conditions inside
  a body, and recursive bodies that compare at their base case. No pinned image
  moved: every pre-existing fixture keeps its exact i386 size and its reviewed
  AArch64/RV64IM golden, because the routine stays at the same offset when the
  main program compares and the extra patching only rewrites existing
  displacements. The new `streq_body` fixture is the only one whose routine is
  reachable only from a body (i386 8361 bytes, reviewed AArch64/RV64IM goldens,
  arch-neutral data image, output compared with the x86-64 native AOT lane) and
  the refusal matrix is 63 (`refuse/streq_in_body.sa` became a legal program and
  was deleted, its forms moved into `streq_body`).

- **Numeric list literals** (2026-11-17, step 15; historical, runtime
  indexing and body lists below supersede the original restrictions): the first aggregate slice.
  `hold xs = [7, 8, 9]` writes the elements into the data segment at compile
  time (this initial subset had no element assignment), `xs[<integer literal>]` lowers to one variable load at
  `base + 4*index`, and `len(xs)` pushes the element count as an immediate.
  Indices are compile-time checked against that count, so `xs[2]` on a
  two-element list is a refusal rather than a fault, and a runtime index is
  refused because a list here is a fixed set of words. Two elements or a
  hundred work; the same list can be read in arithmetic, in `when`/`while`
  conditions and next to `len`. The new `list_num` fixture covers reads, `len`
  in arithmetic, a conditional, a one-element list, a second list and values
  used as loop counters, and agrees on the six execution paths (i386 8272
  bytes, reviewed AArch64/RV64IM goldens, arch-neutral data image, output equal
  to the x86-64 native AOT lane). `refuse/list.sa` became a legal program and
  was replaced by `refuse/list_dynamic_index.sa` and
  `refuse/list_index_past_end.sa`, so the refusal matrix stays 64. Structs, FP
  expressions and file APIs are still open.

- **Numeric list literals inside `make` bodies** (2026-11-17, step 16): the
  step-15 slice is no longer top-level only. A body list reserves its words in
  the frame, growing *downward* from the slot the name path hands out (a frame
  local lives below the frame base), and each element is stored at run time with
  the ordinary `push immediate` + `store variable` pair, so no new encoder is
  involved; a read is one variable load at `slot - 4*index` and `len(xs)` stays
  the compile-time count. Two lists in one body share the frame, a recursive
  body can compare against its own list, and a top-level list in the same
  program keeps the data-segment layout. The new `list_body` fixture covers
  those forms and agrees on the six execution paths (i386 8244 bytes, reviewed
  AArch64/RV64IM goldens, arch-neutral data image, output equal to the x86-64
  native AOT lane); every pre-existing fixture keeps its exact size and golden,
  and the refusal matrix stays 64.

- **Signed list elements** (2026-11-17, step 17): an element may be negative.
  `-` and digits are parsed explicitly (never through the numeric token reader,
  which treats a sign ambiguously) and the value is stored as the 32-bit two's
  complement word, so `hold xs = [-5, 0, 7]` reads back `-5`, `0`, `7`, and
  `xs[0] + xs[2]` is `2` — the same answers as the C backend. Inside a body the
  element goes through the ordinary push-immediate/store-variable pair, so a
  frame list carries signs too. The new `list_neg` fixture covers mixed signs,
  a large negative, arithmetic in both orders, `len`, a conditional on a
  negative element and two body lists, and agrees on the six execution paths
  (i386 8276 bytes, reviewed AArch64/RV64IM goldens, arch-neutral data image,
  output equal to the x86-64 native AOT lane). Every pre-existing fixture keeps
  its exact size and golden and the refusal matrix stays 64.

- **Literal-or-expression list elements** (2026-11-17, step 18): an element no
  longer has to be an integer literal. Anything that is not a literal is
  compiled as an integer expression where the list is declared and stored
  through the slot path a literal uses, so `hold xs = [n, n + 1, n * 2]` works
  inside a body and `hold top = [k, k * k, k - 10]` works at top level, with the
  same literal fast path (data word or immediate) still used for constants and
  the data image still zero-initialized, which keeps the data segment
  arch-neutral. The new `list_expr` fixture covers two body lists built from
  parameters, a negative computed element and a top-level list built from a
  variable, and agrees on the six execution paths (i386 8252 bytes, reviewed
  AArch64/RV64IM goldens, arch-neutral data image, output equal to the x86-64
  native AOT lane). Every pre-existing fixture keeps its exact size and golden
  and the refusal matrix stays 64.

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
  one frame, and `give` outside a body. A call result can feed a call, an
  operator or a condition, but not a `concat` argument.
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

- **String parameters and string-valued functions (2026-11-13):** a parameter may
  be `name: str` and a body may return `-> str`, so `make wrap(s: str) -> str`
  and a mixed `make pad(n: num, s: str, k: num) -> str` both lower on all three
  targets. A string is a `(pointer, length)` pair and therefore occupies **two**
  pushed words where a `num` occupies one; every parameter displacement is
  computed from those widths, which is what makes a mixed parameter list work.
  The caller pushes a pair length-first so the pointer lands at the lower
  address. A 64-bit push is 16 bytes while a pair's fields are 4, so the prologue
  copies each string argument into a compact local pair and the body then reads
  it like any other string local — no string parameter is read in place.
  A `-> str` body publishes its result in one shared absolute pair which the
  caller copies out **immediately**, before any other call can run; that
  ordering is what makes `f(g(x))` and recursion sound with a single slot.
  Accepted positions for a `-> str` call: `show f(…)`, `hold s = f(…)`,
  `s = f(…)`, `len(f(…))`, either `concat` operand, a `str` argument of another
  call, and `give f(…)` in a `-> str` body. A `give` in a `-> str` body takes a
  literal, a string name, `chr(…)`, `concat(…)` or another `-> str` call.
  A string value's storage carries a trailing newline because `show` writes
  length + 1 bytes, so a literal bound as an argument or returned from a body is
  pooled with that newline; a `concat` operand is not, which is why every
  pre-existing image stayed byte-identical.
  The 6-parameter maximum is pinned with alternating `num`/`str` (9 pushed words) and with six `str` parameters.
  Refused with a line-numbered diagnostic: a number or numeric variable as a
  `str` argument, a string as a `num` argument, a number as a `-> str` result, a
  string as a `-> num` result, `f() + 1` or any other numeric use of a `-> str`
  call, a `-> str` result assigned to a numeric variable, a num-returning call as
  a `concat` operand, and any parameter or result type other than `num`/`str`.

**Bounded numeric structs** (2026-11-19, local increment): declarations such
as `struct Point { x, y }` may be inline or multiline. A `hold` may initialize
all fields positionally or by name, with integer expressions; `p.x` reads a
field in arithmetic, conditions and indices; `p.x = <integer expression>`
updates a numeric field. Global fields occupy data words;
function-local fields occupy per-invocation frame words, so recursive calls do
not share their locals. At most 32 types and 32 fields per type are accepted,
and body fields count against the existing 60-word frame cap. Empty, duplicate,
missing, extra, mixed positional/named and invalid fields are refused. Whole
struct values and whole-struct assignment, strings/lists/nested structs as
fields, generics, and typed fields are not implemented by this subset. Numeric
field mutation agrees with seed-min and gen2, but native_aot and the full
native compiler currently refuse that statement form. Initializers
with reordered named fields or compound field expressions run in the seed and
native32 fixtures, but gen2 and native_aot reject some of them; the shared
`struct_num` fixture sticks to their common subset. These differences are not
full struct parity.

**Bounded empty-origin numeric list growth** (2026-11-19, local increment):
`hold xs = []` (also `[ ]`) reserves 16 numeric element words and a runtime
length word. `push(xs, VALUE)` and `xs = push(xs, VALUE)` append one numeric
expression; `len(xs)`, checked reads, and indexed writes use the live length.
The seventeenth append and an index outside the live length exit 1. The list
is reset at each declaration execution and local storage belongs to the call
frame (17 words of the 60-word frame budget). Value expressions run once;
negative indices count from the end. General dynamic allocation, growth beyond
16 elements, aliases, list parameters/returns, whole-list copying or rebinding,
and pushing into nonempty literal lists are not supported. The common fixture
has an independent oracle and runs across the reference and native ISA lanes;
a separate fixture tests frame recursion, declaration reset, maximum capacity,
negative indexing and side effects. The full x86-64 compilers currently fault
on negative list indices; those tests use the C reference lanes instead.

**Fixed-list element assignment** (2026-11-19, local increment):
`xs[INDEX] = VALUE` checks the integer index, then stores the numeric value
into the existing fixed-size list on i386, AArch64 and RV64IM. The index is
evaluated once, negative indices count from the end, and local lists remain
per-frame under recursion. Each execution of a block-local list declaration
reinitializes its literal elements, including on loop iterations. Bounds faults
exit 1. The common positive fixture agrees with seed-min, gen2 and the full
x86-64 compiler; the bounded native_aot profile refuses list assignment. The
full x86-64 compiler currently faults on negative list indices, and seed/gen2
cannot emit some nested-index assignment forms, so those cases have separate
oracles and only the applicable reference lanes. At this stage whole-list rebinding,
aliases, `push`/growth and empty lists were unsupported; see the increment above.

**Fixed-list runtime indices** (2026-11-19, local increment): an index is
computed once and bounds-checked, with negative values counting from the end.
Global lists grow upward in the data image; function-local lists grow downward
in each call frame, including under recursion. Runtime bounds faults exit 1;
literal positive out-of-range indices remain compile-time refusals. The list
name table is now scoped per function, fixing a miscompile when functions use
the same list name with different lengths. Rebinding an existing list or
turning an existing numeric variable into a list is refused rather than
potentially overwriting other slots. This remains fixed-size, not a growing
list implementation. Seed-min and gen2 accept negative list indices, but both
x86-64 native compilers currently exit on them; therefore the negative-index
fixtures compare against the C lanes and independent expected output, not the
x86-64 lane. The shared nonnegative fixture runs across all lanes.

Numeric **list literals** are supported in a bounded form:
`hold xs = [7, 8, 9]` stores the elements in the data segment, `xs[<integer
literal>]` is one variable load at base + 4*index, and `len(xs)` is the
compile-time element count. An element is a signed integer literal or an ordinary integer expression (a
literal is baked into the data segment or pushed as an immediate; anything else
is compiled where the list is declared and stored through the same slot path;
note that v1 lists are numeric only -- the published backends refuse
`hold names = ["ab", "cd"]` with *list elements must be numbers*, so string
elements are not a missing native32 feature),
calls with multiple arguments and nested calls are also accepted as numeric
elements (commas inside a call are not element separators). The scanner also
keeps commas and escaped quotes within string literals together for supported
numeric forms such as `len("a,b")`; the seed grammar rejects that particular
form. An index may be an integer expression, including nested indexing and
calls; negative values count from the end. A positive literal past the end is a
compile-time refusal; runtime out-of-range values exit 1. Empty-origin lists
have the separate bounded growth support documented above; general rebinding and
aliases are not supported. A list literal also works inside a
`make` body: the elements live below the frame base, grow downward from the
reserved word and are stored at run time, so a body list costs one frame word
per element against the same 60-word budget. Top-level literal elements are
placed in the data image; computed elements and body-local elements emit runtime
initialization. General dynamic lists and whole-list rebinding remain unsupported by native32.
Structs are limited to the numeric subset above; floating-point expressions,
general file APIs, and garbage collection remain unsupported by this compiler;
recursion
is supported but capped at 64 live frames, so an unbounded recurrence is a
runtime exit, not a compile-time guarantee. `chr` is accepted as
a whole string value and as one whole argument of `concat`, `string_eq` and
`len`, and nowhere else: an argument that is more than an integer literal or a
numeric variable (`chr(n + 1)`, a signed literal such as `chr(-1)`, `chr("A")`,
`chr(nope)`) is refused in both positions, and a `string_eq` argument may be a
variable, a literal, `chr(...)`, a `concat(...)` or a `-> str` call, but not an
arbitrary string expression. Holding the value first (`hold c = chr(65)`)
remains the way to use it anywhere else. A `string_eq` inside a `make` body is
supported (see *String equality inside `make` bodies*).
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

The `file_io.sa` fixture covers both file builtins on all six execution paths
(i386 image pinned at 12735 bytes, reviewed AArch64/RV64IM goldens, and
`file_io.want` as an independent expectation of the printed span), and runs a write
and a read of a path under a directory that does not exist, which must answer 0 and
the empty string rather than fault. The two refusals are
`refuse/io_dynamic_path.sa` and `refuse/io_num_text.sa`.

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
`concat`, eight-level nesting, and `concat(...)` used inside `string_eq` (that last one became a legal program in the *string equality over string expressions* step and its fixture, `refuse/concat_streq_arg.sa`, was deleted). The
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
  probes, and bounded Linux `openat`/`read`/`write`/`close`/`exit` calls (the
  syscall probes in `tools/sxisaexec_test.sa` stay hand-written images; the
  file-I/O lowering above is what puts the same syscalls in compiler output).
  AArch64 coverage now also includes the
  bit-field and `EXTR` forms, the whole `CSEL`/`CSINC`/`CSINV`/`CSNEG` group with
  its aliases, full 64-bit multiplies and the `*ADDL`/`*SUBL` forms, signed
  integer accesses with the scaled immediate, `FMOV` in both directions,
  `FCVTZS`/`FCVTZU` at both widths, and `BR`/`BLR`/`RET` — pinned case by case by
  `test-sxisaexec` (see
  [the gate log](gate-logs/2026-11-23-arm64-isa-coverage.md)). A word no decoder
  claims is a refusal, not a skip; what is still unsupported is the 64-bit divide
  (which answers from the 32-bit path) and RV64's missing 64-bit
  `mul`/`mulh`/`div`/`rem` (R20).
- `tools/sxisaexec.sa` is written in Sayanox and enforces ELF, memory,
  alignment, instruction, syscall, and step-budget checks. See its source and
  `tools/sxisaexec_test.sa` for the exact emulator boundary.

## Roadmap status

This work is an incremental step toward full AArch64 and RV64GC native compiler
and runtime support. Bounded `concat` and byte indexing extend the original
integer/static-string backend, but do not complete that roadmap item. General
string operations beyond the documented subset (nested `chr`, `show concat(...)`
nested `concat` operands, and `len(concat(...))` are now lowered; concat in
other expression positions is not), general dynamically allocated lists, general structs,
IEEE-754 code generation, and a mark-and-sweep collector remain open, along with
broader ISA support and end-to-end parity for each. Native file I/O landed
2026-11-23 for the two builtins with string-literal paths and one bounded 4 KiB
read; dynamic paths, appending, directory listing and any larger read are still
outside the subset. Do not count emulator-only FP probes as compiler support.

The legacy seed/gen2 reference grammar does not accept a spaced `len (` call or
`len("literal")` directly inside an index. The six-way harness uses
`len_literals_common.sa` (ordinary call spacing and a held numeric index) for
that shared grammar, then separately executes the original native-only forms
on ARM64/RV64 and on i386 when the kernel supports IA32. Both compare with the
same independent `len_literals.want`; these native cases are not discarded or
claimed as new legacy frontend support.
