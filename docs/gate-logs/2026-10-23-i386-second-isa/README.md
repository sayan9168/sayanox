# A second machine-code target: i386, written in Sayanox (2026-10-23)

| Claim | Where it is checked |
|---|---|
| A Sayanox program can be compiled to **32-bit x86 (i386)** Linux machine code by a backend written in Sayanox | `make test-native32` |
| Three fixtures print the same bytes under **four** backends — seed-min (C), gen2 (C), native_aot (x86-64), native32 (i386) | `make test-native32` (`cmp` per fixture per backend) |
| The image really is a different ISA: ELFCLASS32 / ET_EXEC / EM_386, two program headers, entry `0x080480ca`, three pinned sizes — against native_aot's ELFCLASS64 / EM_X86_64 for the same source | `make test-native32` (`od` pins) |
| Emission is byte-deterministic | `make test-native32` (two runs, `cmp`) |
| Nine out-of-subset programs are refused with a diagnostic and exit 1 | `make test-native32` |
| Those refusals are a subset boundary, not a broken front end | the same gate re-runs the legal ones on seed-min; `7 / 2` prints `3.5` |

Row 9 of the status matrix moves from *"no executable second ISA"* to *"an
executable second ISA for a documented integer subset"*. It does **not**
become two complete backends — see "What is still only one ISA" below.

## Why i386 and not ARM64

The decision was made on what this machine can *prove*. A 32-bit ELF runs
here (the canary `show 1` prints `1`), and `objdump` disassembles i386, so an
i386 backend can be gated the way every other backend in this repo is gated:
compile a program, run it, compare the bytes against seed-min. There is no
qemu, no aarch64 toolchain and no aarch64 disassembler available, so an ARM64
emitter could only ever be gated on its own golden bytes — an encoder nobody
has executed. That is the next increment, and it will be labelled as exactly
that.

## What it is

`tools/native32.sa`, ~870 lines of Sayanox, compiled by gen2 into
`tools/native32`:

```
source .sa
  → line-oriented statement scan
  → expression tokenizer (byte-1 separated tokens)
  → shunting-yard walk emitting i386 machine code directly
  → absolute data fixups → ELF32 container (write_bytes)
```

It shares nothing with `selfhost/native_aot.c`. It does not read the
`SX_EMIT_LOG` instruction list, it does not reuse the x86-64 register model,
and it does not go through `tools/sxlink.sa`. Three independent pieces —
front end, encoder, container — in the bootstrap dialect.

Values live on the machine stack; `eax` holds the running value. A binary
operator pops `ecx` then `eax`. `%` is `cdq; idiv ecx; mov eax,edx`; a
comparison is `cmp eax,ecx; setcc al; movzx eax,al`. Names are 4-byte slots
addressed absolutely (`A1 disp32` / `A3 disp32`). `show <number>` calls one
86-byte routine emitted at code offset 0 that divides by ten into a scratch
buffer and makes a single `write(1, …)` through `int 0x80`.

## The subset, and why each refusal exists

Handled: `hold`, assignment, `show` (an integer expression or a string
literal), `when`/`otherwise`, `while`, `+ - * %`, the six comparisons,
parentheses, unary minus, comments.

| Refused | Reason |
|---|---|
| `7 / 2` | a Sayanox number is a double and the answer is 3.5; an integer backend that printed `3` would be lying, so it refuses instead |
| `1.5` | same reason, at the literal |
| a string in a variable | literals are data here, not values; there is no heap |
| `make` / a call | no call frames in v1 |
| a list, a field | no heap, no layouts |
| `&&` / `\|\|` | conditions take one comparison |
| `2147483648` | 32-bit two's complement; the bound is checked at the literal |
| an unclosed `{` | the block stack is non-empty at EOF |

The gate compiles `division.sa`, `strvalue.sa`, `function.sa` and `list.sa`
with seed-min and runs them, so the refusals are demonstrably about this
backend's subset and not about broken programs.

## Bounds that are real

* |value| < 2^31; a *computed* overflow wraps where a double would not.
* `%` by zero raises SIGFPE instead of producing NaN (`idiv` traps).
* Code must fit in the first page (3980 bytes); larger programs are refused
  with the measured size.
* The output file is not chmod +x — `write_bytes` writes bytes.
* Executing the result needs IA32 emulation in the kernel. Without it the
  gate prints `[SKIP]` for the execution half and still checks every byte.

## A gen2 bug found on the way

```
when string_eq(line, "} otherwise {") == 1 {     // gen2: unexpected '"'
```

gen2 scans a condition for the `{` that opens the block **without skipping
string literals**, so a `{` inside a literal inside a condition ends the
condition early. A brace in a literal in statement position is fine, and a
bare `"}"` in a condition is fine; seed-min accepts both. `tools/native32.sa`
builds those two strings with `chr(123)`/`chr(125)` and says why at the site.
Recorded in `docs/FULL_LANGUAGE_SELFHOST.md` and `docs/NATIVE32.md` rather
than fixed: the condition scanner is shared with the act-8 rewrite.

## What is still only one ISA

* `native_aot` is still the only backend that compiles the **native subset**
  (heap, strings, lists, structs, functions, collector, file IO), and it is
  still x86-64 only. `make native-test` is still an x86-64 gate apart from
  the new `test-native32` step.
* There is no aarch64 or riscv64 emitter.
* `tools/emit_to_ir.sa`'s IR listing is still an analysis format that nothing
  assembles or executes; native32 does not read it.

## Gates

```
make test-native32            # the new four-backend gate (now part of native-test)
make test-native-ir-portable  # its [OK] line no longer says "no executable second ISA"
make test-native-emit-split
make test-native-sxlink
make test-doc-claims
make test-language-deps
make test-full-language-expr  # unchanged, re-run as a regression
```

and the four hard gates:

```
make doctor         # DOCTOR-OK
make true-selfhost  # TRUE-SELFHOST-MIN-OK
make gen3           # GEN3-OK (gen3 == gen4)
make native-test    # NATIVE-TEST-OK (test-native32 runs inside)
```

See `hard-gates.log` for the markers and the line numbers this increment's
gates ran at.
