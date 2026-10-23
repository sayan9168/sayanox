# A second machine-code target: i386 (2026-10-23)

`tools/native32.sa` compiles a Sayanox program to a **32-bit x86 (i386)
Linux ELF executable**. It is written in Sayanox, compiled by `selfhost/gen2`,
and it emits machine code and the ELF container itself — no assembler, no
linker, no C.

```sh
make tools/native32
./tools/native32 selfhost/native32_tests/flow.sa /tmp/flow
chmod +x /tmp/flow
/tmp/flow            # 45 1 0 5040 21 10, one per line
```

`make test-native32` is the gate.

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

| | seed-min | gen2 | native_aot | native32 |
|---|---|---|---|---|
| written in | C | Sayanox | C | **Sayanox** |
| output | C source | C source | x86-64 ELF | **i386 ELF** |
| `selfhost/native32_tests/expr.sa` | `14 20 -1 …` | same | same | same |

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
| `make twice(v: num) …` | `make` is not in the i386 subset |
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
* **`%` by zero raises SIGFPE** instead of producing NaN. `idiv` traps; there
  is no floating-point unit in this backend to produce a quiet NaN.
* **Code must fit in the first page** (4096 − 116 = 3980 bytes). Larger
  programs are refused with the measured size in the message.
* **The output is not executable-bit set.** `write_bytes` writes bytes;
  `chmod +x` is the caller's job (the gate does it).
* Running the binaries needs a kernel with IA32 emulation. The gate says
  `[SKIP]` for the execution half if `show 1` cannot run, and still checks
  every emitted byte.

## How it works

```
source .sa
  → line-oriented statement scan
  → per-statement expression tokenizer (byte-1 separated tokens)
  → shunting-yard walk emitting i386 machine code directly
  → absolute data fixups, then the ELF32 container
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

## What the gate checks

`make test-native32`:

1. `expr.sa`, `flow.sa` and `text.sa` produce identical stdout under
   **seed-min, gen2, native_aot and native32** — four backends, two
   instruction sets.
2. The image is ELFCLASS32 / ET_EXEC / EM_386 with two program headers and a
   pinned entry point and size, and `native_aot` on the same source is
   ELFCLASS64 / EM_X86_64.
3. Emission is deterministic: the same source twice gives the same bytes.
4. All nine out-of-subset programs are refused with a diagnostic and exit 1.
5. The legal ones among them still run on seed-min.

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

Row 9 of `docs/STATUS.md` ("a second native ISA") moves from *none* to *an
i386 backend for a documented integer subset, proven by execution*. It does
not become "two complete backends": `native_aot` is still the only backend
that compiles the whole native subset, and there is still no ARM64 target.
