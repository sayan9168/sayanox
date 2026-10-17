# Native instruction log and IR analysis listing

The native AOT compiler does not materialize a portable program IR. Its
maintained pipeline is:

```
source .sa
  → preprocess (use "mod.sa")
  → definition collection and kind inference
  → recursive emit walk (emit_prog / emit_fn / emit_expr)
  → machine-code emission (x86-64 Linux ELF)
```

## Selected native subset surface

| Feature | Native |
|---------|--------|
| hold / show | yes |
| arith / compare | yes |
| when / otherwise / while | yes |
| make / call | yes |
| lists / push / len | yes |
| strings + runtime concat | yes |
| gc() mark/sweep | yes (non-moving chunked heap; see GC.md) |
| use modules | yes |
| write_file / read_file / run | yes |

## Not implemented here

There is no full Stage-2 C host or concurrent pthread collector in this
repository. Full-language self-host and a second machine-code target are not
claimed; see FULL_LANGUAGE_SELFHOST.md and GC.md.

## The instruction list (`SX_EMIT_LOG`, 2026-10-13)

Everything above this section is about the *pipeline*. This section is about the
thing a second backend actually has to reproduce: the instruction list the emit
tree asks the x86-64 encoder for.

`native_aot` records that list when `SX_EMIT_LOG` names a file:

```sh
SX_EMIT_LOG=/tmp/hello.log ./selfhost/native_aot examples/native_hello.sa /tmp/hello
head -20 /tmp/hello.log
```

Every encoder primitive — the ones `make test-native-emit-split` proves are the
only path from the language-level emitter to the machine — writes one line: the
code offset the instruction starts at, the mnemonic, and the operands in
assembly order. Lines beginning with `;` are not instructions. They are the
label slots, the fixups that resolve them, one marker per emitted `make`, and
one marker per phase.

`hold n = twice(20) + 2` from `selfhost/native_ir_log_test.sa`, verbatim:

```text
;       === phase: top level ===
000059  mov rax,0x4034000000000000
000063  push rax
000064  pop rdi
000065  call make twice
00006a  push rax
00006b  mov rax,0x4000000000000000
000075  pop rcx
000076  movq xmm0,rcx
00007b  movq xmm1,rax
000080  addsd xmm0,xmm1
000084  movq rax,xmm0
000089  mov [r12+672],rax
```

Read it with the value model in mind: `0x4034000000000000` is 20.0 and
`0x4000000000000000` is 2.0, because a Sayanox number is an IEEE double held as
raw bits in a 64-bit slot; the first argument goes to `rdi` because the backend
follows System V AMD64; `+` on two numbers is SSE2 `addsd` through
`xmm0`/`xmm1`; `r12` is the data base, so `[r12+672]` is the global slot the
`hold` bound; and the `call make twice` line names its target, because every
call target in the list is named — a `make` by its source name, a runtime stub
by its `B_*` enum name.

A `for` loop shows both halves of the relocation model: a forward branch emitted
with a placeholder and resolved once its target exists, a back edge resolved
immediately.

```text
000173  ucomisd xmm0,xmm1
000177  jae rel32(0)
00017d  call builtin gccheck
...
0001e9  jmp rel32(-167)
;       fixup rel32 [000177] -> 0001ee (113)
0001ee  call builtin gccheck
```

### What a second backend has to reproduce

* **The vocabulary.** `make test-native-ir-log` pins the mnemonics the
  fixture's top level uses —
  `add addsd call cvtsi2sd cvttsd2si jae je jmp lea mov movq movzx mulsd pop push seta ucomisd` —
  and the named call targets (`call make twice`, `call builtin concat`,
  `call builtin gccheck`). A future riscv64/ARM64 backend would need an ABI-aware lowering adapter,
  not just a different byte encoder: these primitive calls still assume
  x86 registers, stack behavior and instruction semantics.
* **The value model.** Numbers are IEEE double bits in 64-bit slots and
  registers; arithmetic moves them through `xmm0`/`xmm1` (`emit_d2i` and
  `emit_i2d` are the two conversions); a list length or a `len()` result is an
  integer on the way back to a double. Strings, lists, files and `show` are
  runtime stubs, so a new backend needs its own versions of the 30 builtins in
  the `B_*` enum.
* **The relocation model.** `sub_rsp_imm32_slot`, `jmp5_slot` and
  `lea_r12_data` return the offset of a placeholder; `patch_imm32`, `erel32`
  and `erel32j` fill it once the target is known; `call_p` records the call site
  in `patch_call[]` and `write_elf` resolves it against `F[].start`, which is
  why a forward call to a `make` works. Each `;` line in the log is one of those
  events.
* **The two inherited contracts** named in [NATIVE.md](NATIVE.md): the System V
  AMD64 calling convention (`rax`/`xmm0` returns, the frame
  `sub_rsp_imm32_slot` opens and `leave_ret` closes) and the collector's block
  layout (`BH_HDR`, the `BK_*` kinds).

### The portable IR listing (`tools/emit_to_ir.c`, 2026-10-15)

`tools/emit_to_ir.c` translates an `SX_EMIT_LOG` instruction list into a
portable *listing*: x86-64 registers become abstract registers (`rax`->`A`,
`xmm0`->`F0`, `rsp`->`SP`, `r12`->`BASE`), byte offsets become sequential
instruction numbers (`I0`, `I1`, ...), integer and floating-point mnemonics
are distinguished (`add`->`IADD`, `addsd`->`FADD`, `cvtsi2sd`->`I2F`), and
call targets keep the names the log already gives them (`CALL make twice`,
`CALL builtin shownum`). Phase markers and label slots stay as comments, and
an unrecognised mnemonic passes through upper-cased with its operands
renamed, so the translation never silently drops an instruction.

```sh
SX_EMIT_LOG=/tmp/hello.log ./selfhost/native_aot examples/native_hello.sa /tmp/hello
make tools/emit_to_ir
./tools/emit_to_ir /tmp/hello.log /tmp/hello.ir
```

`make test-native-ir-portable` pins the contract: the translation is
deterministic (two runs cmp clean), instruction-count preserving (one listing
instruction per logged instruction), free of x86 register names on instruction lines, and preserves
the abstract machine model (`FADD`, `FCMP`, `I2F`, named calls, phase
markers).

This is the "portable IR docs + tests" half of the second-target item, and it
is deliberately only that: **no backend assembles or executes the IR, and no
second ISA is claimed.** The listing exists so the stream can be read, diffed and counted with
abstract register names. Width distinctions and x86-64 semantics are not
removed by renaming; this is not a lossless executable representation. `native-test` stays an x86-64-Linux-only gate.

### What the recorder is not

It is not a portable IR, and it is not a second target. The list is still
x86-64-shaped: the emit tree picks the registers, spills through `push`/`pop`,
and assumes the calling convention above. A new backend replaces the encoder
region, the phase-4 stubs, the collector and the ELF container, and inherits
those choices. This repository still has exactly one emitter of machine code.

The recorder is inert. It only reads the primitives' arguments, never `code` or
`cn`, so the emitted ELF is byte-identical with and without `SX_EMIT_LOG` —
checked against the pre-recorder compiler on six fixtures, and re-checked on
every run of `make test-native-ir-log`, which also cmp's two logged runs against
each other, checks the log's own invariants (every line is an instruction line
or a comment line, the offsets never go backwards, every rel32 fixup lands on a
jump, no call target or operand falls back to a placeholder name, the six phases
come in order), pins the fixture's output, and asserts that the language emitter
never touches the recorder state.

The translator is now streaming C99 (one growable line, not a whole-log array).
`make test-emit-to-ir` checks exact output, token boundaries, named-call
preservation, unknown instructions/lines, long lines, EOF and I/O errors.
The Python implementation has been removed; `native-test` builds and runs the
C tool. The baseline fixture translation matches the former Python output
byte-for-byte after the three provenance header lines. Register abstraction
still does not remove x86 layout/ABI assumptions or resolve relocations.

## Strict log audit and source-offset correlation (2026-10-16)

The streaming C99 translator now offers opt-in analysis modes:

```sh
./tools/emit_to_ir --strict --source-offsets input.log output.ir
```

* `--strict` accepts semicolon comment lines or nonempty instruction records
  with exactly six lowercase hexadecimal offset digits and two spaces before
  the mnemonic. It rejects malformed/empty records and decreasing instruction
  offsets, with a line-numbered diagnostic and nonzero status. Equal offsets
  are allowed; comments are not interpreted as control-flow assertions.
* `--source-offsets` adds a comment before each instruction, e.g.
  `; source-offset 000059 -> I7`, so a listing instruction can be correlated
  with the recorded machine-byte offset and original fixup comments.
* Existing two-positional-argument usage is unchanged. Default mode retains
  malformed/unknown lines as `UNTRANSLATED` comments. Unknown **mnemonics** are
  retained uppercased even in strict mode: this validates the log record shape,
  not the instruction set or operand semantics. NUL bytes and I/O errors fail
  in both modes. A failed run can leave a partial output; callers must check
  its exit status. `--` ends option parsing.

`test-emit-to-ir` checks exact audit output, repeated-offset acceptance,
backward/malformed/NUL refusal, unterminated final lines, long operands and
unchanged default output. `test-native-ir-portable` runs both modes on a real
native compilation, compares repeat audit runs, checks one correlation comment
per instruction, and proves that stripping only those added comments gives
back the default listing. This is part of `native-test`, using C and shell
utilities only—no Python.

### Explicit non-claims

The default mapping collapses, for example, `rax`, `eax` and `al` to `A`.
That loses width information. It also retains x86-relative displacements,
System V AMD64 register roles, stack operations, condition-code assumptions,
SSE operations and syscall/runtime choices. “One instruction per record” is
not a semantic-losslessness claim. Source offsets are byte offsets in the
recorded x86 program, **not** portable branch labels; neither mode resolves
fixups, builds a CFG/SSA, checks operands, assembles, interprets or executes the
listing. Strict success does not prove that a log describes valid machine code.

There is still exactly **one executable ISA backend: x86-64 Linux ELF**.
No aarch64/riscv64 emitter, loader, ABI/runtime/collector port, cross-execution
smoke test or second-backend acceptance gate has been added. Host-C compilation
of generated C and abstract register names are not a second native ISA.
Actual gates: [2026-10-16 IR/modules logs](gate-logs/2026-10-16-ir-modules/).
