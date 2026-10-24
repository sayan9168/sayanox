# A third machine-code target: aarch64, written in Sayanox (2026-10-23)

The previous log in this folder, `2026-10-23-i386-second-isa/README.md`, ends
its "Why i386 and not ARM64" section with:

> There is no qemu, no aarch64 toolchain and no aarch64 disassembler
> available, so an ARM64 emitter could only ever be gated on its own golden
> bytes — an encoder nobody has executed. **That is the next increment, and it
> will be labelled as exactly that.**

This is that increment, labelled as exactly that.

| Claim | Where it is checked |
|---|---|
| The same `tools/native32.sa`, given `arm64`, emits an **AArch64 Linux ELF64** for the documented integer subset | `make test-native-arm64` |
| The three images are byte-deterministic and byte-identical to goldens that were disassembled and read instruction by instruction | `make test-native-arm64` (two runs + `cmp` against `selfhost/native32_tests/golden/*.arm64.elf`) |
| The container really is AArch64: ELFCLASS64 / ET_EXEC / **EM_AARCH64 (183)**, `e_phentsize` 56, two PHDRs, entry `0x400134`, text `0x400000`, data `0x401000` | `make test-native-arm64` (`od` pins) |
| Two instruction sequences are pinned as raw bytes, not just by the golden: the print-routine prologue `mov w4, w0` and the exit `mov x0,#0` / `mov x8,#93` / `svc #0` | `make test-native-arm64` (`od` at byte 176 and at `p_filesz − 12`) |
| **One front end, two encoders:** for each fixture the i386 and arm64 images lay out a byte-identical *data* segment while their *text* segments differ | `make test-native-arm64` (`tail -c +4097` + `cmp`, plus a negative `cmp` on the whole image) |
| The subset boundary does not move with the target: the same nine programs are refused for `arm64`, and an unknown target name is an error | `make test-native-arm64` |
| The i386 target did not regress: same sizes, same four-backend stdout, same pins | `make test-native32` (unchanged, re-run on this tree) |

## What this does NOT claim

**No arm64 image is executed anywhere in this repository.** This is an x86-64
machine with no emulator, no cross-assembler, no aarch64 `objdump` and no ARM
hardware. Nothing in `make`, in CI, or in any script runs one of these files.
Every `[OK]` line on the gate says "never executed in this repository", and
the STATUS row and `docs/NATIVE32.md` say the same thing in the same words.

So the honest strength of this increment is: **the bytes are pinned and the
bytes have been read.** It is weaker than the i386 increment, which is pinned
*and* executed *and* compared against three other backends. The two are
deliberately not described with the same verb.

## What was built

No new program and no copied parser. `tools/native32.sa` grew a second
encoder behind an `arch` parameter (0 = i386, 1 = arm64), selected by the
third command-line argument:

```sh
./tools/native32 prog.sa out            # i386   (default, unchanged)
./tools/native32 prog.sa out i386       # same bytes as the default
./tools/native32 prog.sa out arm64      # AArch64 ELF64
./tools/native32 prog.sa out sparc      # exit 2: native32: unknown target 'sparc'
```

The line scan, the tokenizer, the shunting-yard walk, the slot allocator, the
block bookkeeping and all nine refusals are shared code — which is why the
gate can assert that both targets produce the *same data segment* for the
same source. What differs is twelve `emit_*` helpers and the container
writer. File: 1437 lines, up from 1276.

| | i386 | arm64 |
|---|---|---|
| accumulator / right operand | `eax` / `ecx` | `w0` / `w1` |
| push / pop | `50` / `58` | `str x0,[sp,#-16]!` / `ldr x0,[sp],#16` |
| `%` | `cdq; idiv ecx; mov eax,edx` | `sdiv w2,w0,w1; msub w0,w2,w1,w0` |
| comparison | `cmp; setcc al; movzx eax,al` | `cmp w0,w1; cset w0,cc` |
| address of a name | absolute `disp32` | `movz` + `movk lsl 16` into `x9` |
| branch | `jz`/`jmp rel32`, bytes from the end of the instruction | `b.eq imm19` / `b imm26`, **instructions** from the branch itself |
| write / exit | `int 0x80`, eax=4 / eax=1 | `svc #0`, x8=64 / x8=93 |
| print routine | 86 bytes | 132 bytes (33 words) |
| container | ELF32, `EM_386`, `0x08048000` | ELF64, `EM_AARCH64`, `0x400000` |

Both emitters leave their patch site at `len(code) - 4`, so `run()`'s block
bookkeeping needed no arch test at all — only `patch_jz` / `patch_jmp` know
that AArch64 counts instructions and divides the delta by four.

## How the bytes were verified, in order

1. **Every encoding was checked against a disassembler before it went into
   the emitter.** This caught **ten wrong constants** in the first draft —
   all of them hand hex-to-decimal conversion errors (`0x52800000` written as
   `1484783616` instead of `1384120320`, and nine more). None of them would
   have been caught by a size pin or a determinism check; several decoded as
   *valid but completely different* instructions (`movz w0,#0` had become
   `ldr x0, #0xfffffffffff01000`).
2. **The print routine was assembled and disassembled standalone**, including
   its three patched branch displacements, before being transcribed into
   Sayanox.
3. **The three emitted images were disassembled in full and read instruction
   by instruction** — 292, 457 and 79 instructions. The listings are in this
   folder: `expr.arm64.dis`, `flow.arm64.dis`, `text.arm64.dis`. Branch
   targets were checked by hand: the `while` back edge lands on the first
   instruction of the condition, the `when` false-branch lands after the
   block, and the `otherwise` jump clears the else arm.
4. **An instruction-exact interpreter was written for the subset** at
   authoring time and the three images were executed under it. All three
   printed output byte-identical to seed-min's C output (`45 1 0 5040 21 10`
   for `flow.sa`, and so on). The interpreter **errors on any word it does
   not recognise**, so it also proves the emitter produced nothing outside
   the reviewed encoding set.
5. **The reviewed images were committed as goldens** and the gate compares
   every byte.

Steps 1–4 used tools that are **not in this repository and not referenced by
any make target** — a gate that needed Python would violate
`test-language-deps`, which bans python/bash/awk/sed/perl/node/ruby from the
build and test paths. They are authoring-time evidence, recorded here so the
review is reproducible by anyone with a disassembler; the *gate* stands on
the golden bytes alone.

## The four markers

```
DOCTOR-OK
TRUE-SELFHOST-MIN-OK
gen3 == gen4 (byte-identical)
NATIVE-TEST-OK
```

See `hard-gates.log` in this folder for the full run with timestamps.

## gen3 == gen4

`make gen3` rebuilds gen3 from gen2 and gen4 from gen3 and requires the two
C outputs to be byte-identical. Unchanged by this work: nothing in this
increment touches `selfhost/compiler_min.sa`. The only compiler-side
dependency is that gen2 can compile `tools/native32.sa`, which the
`tools/native32` rule checks by rejecting any `#error` in the generated C.

## Increment gates on this tree

| Gate | Makefile line | What it adds |
|---|---|---|
| `test-native-arm64` | 2195 (`.PHONY` 2194, `native-test:` 2258, aggregate line 43) | the whole arm64 claim above, four `[OK]` lines |
| `test-native32` | 2098 | unchanged, re-run to prove the i386 path did not move |

Files added: `selfhost/native32_tests/golden/{expr,flow,text}.arm64.elf`
(12 497 bytes total — tracked on purpose: with no way to execute them, the
golden *is* the oracle), and the three `.dis` listings here.

## Run on the same tree, outside the four aggregates

```
make -o restore-compiler -o selfhost/gen2 -o selfhost/gen3 \
     test-native32 test-native-arm64 test-native-ir-portable \
     test-native-emit-split test-doc-claims test-language-deps \
     test-full-language-expr test-native-sxlink
```

EXIT=0 in 14 s.

## Two things that cost time

* **Ten wrong constants** (above). The lesson is in the method, not the
  arithmetic: no hand-written machine-code constant went into the second
  draft without a disassembler round trip first.
* **A `write_file` that never happened.** The first edit script asserted
  uniqueness on ten replacement patterns and wrote the file only at the end;
  pattern nine did not match, the script aborted, and *nothing* was written —
  including the ELF64 writer that was in the same script. The build then
  failed with `#error sayanox-min: unknown function: elf64_arm`, which looked
  like a gen2 scoping problem for a few minutes. Fail-fast assertions plus a
  single trailing write is the right pattern, but the failure has to be read
  as "nothing was applied", not "part of it was applied".

## After the run above

`selfhost/seed/sxc_seed` is rebuilt by the gates and was restored with
`git checkout --` before committing, as in the previous log. `tools/native32`
stays in `.gitignore`.

## What is still only one ISA

* `native_aot` — the backend for the **native subset** — is x86-64 Linux
  only. Heap, strings, lists, structs, functions, the collector and file IO
  exist on no other target.
* There is no riscv64 emitter.
* There is **no execution evidence for aarch64**, and there cannot be on this
  machine. If this repository ever gains qemu-user, a cross toolchain or an
  ARM runner, the upgrade path is already scoped: run the three goldens,
  compare stdout with `selfhost/seed_tests/n32/*.want`, and change the `[OK]`
  wording from "emitted and pinned" to "executed". Until then the wording
  stays.
