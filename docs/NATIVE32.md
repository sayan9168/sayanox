# Second, third and fourth machine-code targets: i386, arm64 and riscv64

`tools/native32.sa` compiles a Sayanox program to a **32-bit x86 (i386) Linux
ELF executable**, — with `arm64` as its third argument — to a **64-bit ARM
(AArch64) Linux ELF executable**, or — with `riscv64` as its third argument —
to a **64-bit RISC-V (RV64IM, `EM_RISCV = 243`) Linux ELF executable**. It is
written in Sayanox, compiled by `selfhost/gen2`, and it emits machine code and
the ELF container itself — no assembler, no linker, no C.

```sh
make tools/native32
./tools/native32 selfhost/native32_tests/flow.sa /tmp/flow          # i386
chmod +x /tmp/flow
/tmp/flow            # 45 1 0 5040 21 10, one per line

./tools/native32 selfhost/native32_tests/flow.sa /tmp/flow.a64 arm64
./tools/native32 selfhost/native32_tests/flow.sa /tmp/flow.rv64 riscv64
```

`make test-native32`, `make test-native-arm64` and `make test-native-riscv64`
are the gates.

**Read this before the rest:** the i386 images are *executed* by the gate on
this machine and their stdout is compared with three other backends. The
arm64 images are **never executed anywhere in this repository** — it is an
x86-64 machine with no emulator, no cross-assembler and no aarch64
`objdump`. The arm64 claim is therefore deliberately weaker, and the gate
and the `[OK]` lines say which is which.

## What it is

Until today the only machine-code backend was `selfhost/native_aot.c`:
x86-64, written in C. `docs/STATUS.md` carried *"a second native ISA: none —
x86-64 Linux only"*, and `docs/NATIVE_IR.md` described what a second backend
would have to reproduce.

This is a second backend that reproduces none of it. It has its own front
end, its own encoder and its own container writer. What it demonstrates is
narrow and checkable: **a Sayanox program can become machine code for an
instruction set that is not x86-64, and the result prints the same bytes as
the other three backends.**

| | seed-min | gen2 | native_aot | native32 i386 | native32 arm64 |
|---|---|---|---|---|---|
| written in | C | Sayanox | C | **Sayanox** | **Sayanox** |
| output | C source | C source | x86-64 ELF | **i386 ELF** | **AArch64 ELF** |
| `expr.sa` stdout | `14 20 -1 …` | same | same | same, *executed* | not executed here |
| how it is checked | run | run | run | run + byte pins | byte pins + golden + disassembly review |

## What it is not

It is **not** the native subset, and it does not replace `native_aot`. It
handles the integer subset below and refuses everything else by name, with a
diagnostic and exit 1. There is no heap, no string values, no lists, no
structs, no functions, no collector and no file IO.

## The subset, exactly

```
hold NAME = <integer expression>     a name is a 4-byte global slot
NAME = <integer expression>          a repeated `hold` assigns the same slot
show <integer expression>            decimal, then a newline
show "literal"                       the literal bytes, then a newline
when <expression> { … }              zero is false, non-zero is true
} otherwise { … }
while <expression> { … }
// comments, blank lines
```

Expressions: `+ - * %`, the six comparisons, parentheses, unary minus,
decimal integer literals and names.

### Refused, each with its reason

| Program | Diagnostic |
|---|---|
| `show 7 / 2` | division: a Sayanox number is a double and `7 / 2` is 3.5, which an integer backend cannot print |
| `show 1.5` | a fractional number (this backend has no doubles) |
| `hold s = "x"` then `show s` | the character `"` in an expression — literals are data, not values |
| `make twice(v: num) …` | `make` is not in the native32 subset |
| `hold xs = [1, 2]` | the character `[` in an expression |
| `show y` (undeclared) | unknown name `y` |
| `when a == 1 && a < 2 {` | `&&`: conditions take one comparison here |
| `show 2147483648` | an integer literal of 2^31 or more |
| an unclosed `{` | a block is still open at the end of the program |

The gate re-compiles the legal ones (`division`, `strvalue`, `function`,
`list`) with seed-min and runs them, so each refusal is demonstrably a subset
boundary rather than a broken front end: `7 / 2` prints `3.5` there.

## Bounds that are real

* **|value| < 2^31.** Arithmetic is 32-bit two's complement. Literals of 2^31
  or more are refused at compile time; a *computed* overflow wraps, where the
  double-based backends would keep going. Stay inside the bound.
* **`%` by zero raises SIGFPE on i386** instead of producing NaN. `idiv`
  traps; there is no floating-point unit in this backend to produce a quiet
  NaN. **On arm64 it does not trap**: `sdiv` by zero yields 0, so `x % 0`
  evaluates to `x`. That is a difference between the two targets, documented
  rather than papered over — the subset's contract is "don't divide by zero".
* **Code must fit in the first page** (4096 − 116 = 3980 bytes on i386,
  4096 − 176 = 3920 on arm64). Larger programs are refused with the measured
  size in the message.
* **The output is not executable-bit set.** `write_bytes` writes bytes;
  `chmod +x` is the caller's job (the gate does it).
* Running the i386 binaries needs a kernel with IA32 emulation. The gate says
  `[SKIP]` for the execution half if `show 1` cannot run, and still checks
  every emitted byte.
* **The arm64 binaries are not run at all** — not by the gate, not by hand,
  not once. Everything asserted about them is a property of the bytes.

## How it works

```
source .sa
  → line-oriented statement scan
  → per-statement expression tokenizer (byte-1 separated tokens)
  → shunting-yard walk emitting machine code directly, through one
    arch-parameterised emitter surface (i386 or arm64)
  → absolute data fixups, then the ELF32 or ELF64 container
```

* **Values** live on the machine stack. An operand is loaded into `eax` and
  pushed; a binary operator pops `ecx` then `eax`, computes into `eax` and
  pushes. `%` is `cdq; idiv ecx; mov eax,edx`; a comparison is
  `cmp eax,ecx; setcc al; movzx eax,al`.
* **Names** are 4-byte slots in the data segment, addressed absolutely
  (`A1 disp32` / `A3 disp32`). A slot is allocated wherever the data segment
  currently ends, because string literals share the same buffer.
* **Blocks** push a patch site. `when` emits `test eax,eax; jz rel32`, and the
  `}` writes the distance back into the slot. `while` records the offset
  *before* the condition and `}` emits `jmp rel32` back to it. `otherwise`
  emits a forward `jmp` and rebinds the pending site.
* **`show <number>`** calls one 86-byte routine emitted at code offset 0: it
  takes the sign, divides by 10 into a 32-byte scratch buffer at data offset
  0, writes the minus if needed, appends the newline and makes one
  `write(1, …)` syscall through `int 0x80`.
* **`show "literal"`** copies the bytes (escapes resolved at compile time)
  into the data segment and emits the same `write` syscall inline.
* **The container** is two `PT_LOAD` segments: headers + code read/execute at
  `0x08048000`, data read/write at `0x08049000`. The entry point is
  `0x080480ca` — base + 116 header bytes + the 86-byte print routine.

## The arm64 encoder

The second encoder shares everything above the instruction level: the same
line scan, the same tokenizer, the same shunting-yard walk, the same slot
allocator, the same refusals. Only the twelve `emit_*` helpers differ, and
they are selected by an `arch` argument threaded through `run()` — so a bug
in the front end is a bug on both targets, which is the point of putting
them in one program.

| | i386 | arm64 |
|---|---|---|
| accumulator / right operand | `eax` / `ecx` | `w0` / `w1` |
| push / pop | `50` / `58` | `str x0,[sp,#-16]!` / `ldr x0,[sp],#16` |
| `+ - *` | `01 C8` / `29 C8` / `0F AF C1` | `add` / `sub` / `mul w0,w0,w1` |
| `%` | `cdq; idiv ecx; mov eax,edx` | `sdiv w2,w0,w1; msub w0,w2,w1,w0` |
| comparison | `cmp; setcc al; movzx eax,al` | `cmp w0,w1; cset w0,cc` |
| address of a name | absolute `disp32` in the instruction | `movz`+`movk lsl 16` into `x9` |
| conditional branch | `test eax,eax; jz rel32` | `cmp w0,#0; b.eq imm19` |
| back edge / jump | `jmp rel32` | `b imm26` |
| call / return | `E8 rel32` / `C3` | `bl imm26` / `ret` |
| write / exit | `int 0x80`, eax=4 / eax=1 | `svc #0`, x8=64 / x8=93 |
| print routine | 86 bytes at code offset 0 | 132 bytes (33 words) at code offset 0 |
| container | ELF32, `EM_386`, base `0x08048000` | ELF64, `EM_AARCH64` (183), base `0x400000` |
| entry point | `0x080480ca` | `0x400134` |

Branch displacements are the one real asymmetry: i386 counts bytes from the
end of the instruction, AArch64 counts *instructions* from the branch itself,
so `patch_jz` / `patch_jmp` divide by four and write a 19- or 26-bit field.
Both emitters are arranged so the patch site is at `len(code) - 4` after the
helper returns, which is why the block bookkeeping in `run()` needs no arch
test at all.

### How the arm64 output was verified, exactly

Honesty matters more here than anywhere else in the repository, because
nothing executes these bytes:

1. **Every encoding was checked against a disassembler before it was
   written into the emitter.** Ten of the first constants were wrong (hand
   hex-to-decimal conversion); the disassembler caught all ten.
2. **The three emitted images were disassembled in full and read
   instruction by instruction** — 292 instructions for `expr.sa`, including
   every branch target. The listings are in
   `docs/gate-logs/2026-10-23-arm64-third-isa/`.
3. **An instruction-exact interpreter for the subset was written at
   authoring time** and the three images were executed under it; all three
   printed bytes identical to seed-min's C output. The interpreter rejects
   any word it does not recognise, so it also proves the emitter never
   produced an encoding outside the reviewed set. It is a scratch tool, it
   is not in this repository, and **no gate depends on it** — a gate that
   needs a Python interpreter would violate `test-language-deps`.
4. **The reviewed images are committed as goldens**
   (`selfhost/native32_tests/golden/*.arm64.elf`) and `make
   test-native-arm64` compares every byte against them.

What none of that is: proof that the images run on real hardware. They have
never been near an ARM core. The claim this repository makes is "emitted,
pinned and reviewed", and that is the claim the `[OK]` lines print.

## What the gates check

`make test-native32` (i386):

1. `expr.sa`, `flow.sa` and `text.sa` produce identical stdout under
   **seed-min, gen2, native_aot and native32** — four backends, two
   instruction sets.
2. The image is ELFCLASS32 / ET_EXEC / EM_386 with two program headers and a
   pinned entry point and size, and `native_aot` on the same source is
   ELFCLASS64 / EM_X86_64.
3. Emission is deterministic: the same source twice gives the same bytes.
4. All nine out-of-subset programs are refused with a diagnostic and exit 1.
5. The legal ones among them still run on seed-min.

`make test-native-arm64`:

1. The three fixtures are accepted for `arm64`, emitted twice with identical
   bytes, and compared byte for byte with the reviewed goldens.
2. The container is ELFCLASS64 / ET_EXEC / **EM_AARCH64**, `e_phentsize` 56,
   two program headers, entry `0x400134`, text at `0x400000`, data at
   `0x401000`.
3. Two instruction sequences are pinned as raw bytes rather than left to the
   golden alone: the first word of the print routine (`mov w4, w0`) and the
   last three words of the text segment (`mov x0,#0` / `mov x8,#93` /
   `svc #0`).
4. **One front end, two encoders:** for each fixture the i386 and arm64
   images must lay out a *byte-identical data segment* while their text
   segments differ. That ties the two targets to the same front end without
   running either.
5. The nine refusals refuse on this target too, and an unknown target name
   (`sparc`) is an error rather than a silent default to i386.

Nothing in `test-native-arm64` executes an arm64 image, and its `[OK]` lines
say so in words.

## A gen2 limitation found while writing this

A `{` inside a **string literal in a `when` condition** is read by gen2 as the
block opener:

```
when string_eq(line, "} otherwise {") == 1 {     // gen2: unexpected '"'
```

A brace in a literal in *statement* position is fine, and so is a bare `"}"`
in a condition; it is the condition scanner. `tools/native32.sa` builds those
two strings with `chr(123)` / `chr(125)` instead, with a comment saying why.
seed-min accepts both forms. This is a gen2 divergence, not a language rule —
recorded here and in `docs/FULL_LANGUAGE_SELFHOST.md`.

## Where this leaves the roadmap row

Row 9 of `docs/STATUS.md` ("a second native ISA") moves from *none* to *two
further ISAs for a documented integer subset: i386, proven by execution, and
AArch64, emitted and byte-pinned but never executed here*. It does not become
"three complete backends": `native_aot` is still the only backend that
compiles the whole native subset, and the arm64 target has no evidence from
real hardware — only from its bytes.

If this repository ever gains a way to run AArch64 (a qemu-user binary, a
cross toolchain, an actual ARM runner), the honest next step is small and
already scoped: run the three goldens, compare stdout with
`selfhost/seed_tests/n32/*.want`, and upgrade the `[OK]` line from "emitted
and pinned" to "executed". Until then the wording stays as it is.
