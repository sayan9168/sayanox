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
repository. Published-language v1 C-output self-hosting is accepted; this
native pipeline still has its own bounded subset. See FULL_LANGUAGE_SELFHOST.md
and GC.md. A separate multi-ISA machine-code compiler exists
since 2026-10-23 for a documented integer subset only —
[NATIVE32.md](NATIVE32.md), `./sx target test-native32` — and it is a separate
program, not this pipeline: nothing below assembles or executes this IR.

## The instruction list (`SX_EMIT_LOG`, 2026-10-13)

Everything above this section is about the *pipeline*. This section is about the
thing a second backend actually has to reproduce: the instruction list the emit
tree asks the x86-64 encoder for.

`native_aot` records that list when `SX_EMIT_LOG` names a file:

```sh
SX_EMIT_LOG=/tmp/hello.log ./selfhost/native_aot examples/native_hello.sa /tmp/hello
head -20 /tmp/hello.log
```

Every encoder primitive — the ones `./sx target test-native-emit-split` proves are the
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

* **The vocabulary.** `./sx target test-native-ir-log` pins the mnemonics the
  fixture's top level uses —
  `add addsd call cvtsi2sd cvttsd2si jae je jmp lea mov movq movzx mulsd pop push seta ucomisd` —
  and the named call targets (`call make twice`, `call builtin concat`,
  `call builtin gccheck`). A future riscv64/ARM64 backend *for the native
  subset* would need an ABI-aware lowering adapter, not just a different byte
  encoder: these primitive calls still assume x86 registers, stack behavior
  and instruction semantics. (`tools/native32.sa` sidesteps that by compiling
  a far smaller integer subset with no calls into the runtime at all, which is
  exactly why its two targets could share one front end.)
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

### The portable IR listing (`tools/emit_to_ir.sa`, 2026-10-15; Sayanox since 2026-10-17)

`tools/emit_to_ir.sa` translates an `SX_EMIT_LOG` instruction list into a
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
./sx tool emit_to_ir
./tools/emit_to_ir /tmp/hello.log > /tmp/hello.ir
```

The tool is a Sayanox program compiled by `gen2` and then `cc`; it writes the
listing to stdout (Sayanox has no file mode argument), so call sites redirect.
Its input is read as a C string, so a NUL byte truncates the log; the script
`tools/test-emit-to-ir.sh` pins that this truncation shows up as an explicit
`; UNTRANSLATED:` comment rather than silence.

`./sx target test-native-ir-portable` pins the contract: the translation is
deterministic (two runs cmp clean), instruction-count preserving (one listing
instruction per logged instruction), free of x86 register names on instruction lines, and preserves
the abstract machine model (`FADD`, `FCMP`, `I2F`, named calls, phase
markers).

This is the "portable IR docs + tests" half of the second-target item, and it
is deliberately only that: **no backend assembles or executes the IR.** (The
executable second target added on 2026-10-23, `tools/native32.sa`, does not
read this listing either; it is an independent front end and encoder for a
documented integer subset — [NATIVE32.md](NATIVE32.md).) The listing exists so the stream can be read, diffed and counted with
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
every run of `./sx target test-native-ir-log`, which also cmp's two logged runs against
each other, checks the log's own invariants (every line is an instruction line
or a comment line, the offsets never go backwards, every rel32 fixup lands on a
jump, no call target or operand falls back to a placeholder name, the six phases
come in order), pins the fixture's output, and asserts that the language emitter
never touches the recorder state.

The translator is now streaming C99 (one growable line, not a whole-log array).
`./sx target test-emit-to-ir` checks exact output, token boundaries, named-call
preservation, unknown instructions/lines, long lines, EOF and I/O errors.
The Python implementation has been removed; `native-test` builds and runs the
C tool. The baseline fixture translation matches the former Python output
byte-for-byte after the three provenance header lines. Register abstraction
still does not remove x86 layout/ABI assumptions or resolve relocations.

## Strict log audit and source-offset correlation (2026-10-16)

The translator now offers opt-in analysis modes:

```sh
./tools/emit_to_ir --strict --source-offsets input.log > output.ir
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

As of this section's date there was exactly **one executable ISA backend:
x86-64 Linux ELF**. No aarch64/riscv64 emitter, loader, ABI/runtime/collector
port, cross-execution smoke test or second-backend acceptance gate had been
added, and host-C compilation of generated C and abstract register names are
not a second native ISA. (Later: 2026-10-23 added `tools/native32.sa`, an
i386 backend for a documented integer subset with its own acceptance gate,
`./sx target test-native32`, and an aarch64 encoder in the same program,
`./sx target test-native-arm64`, whose images are emitted and byte-pinned but
never executed here. Still no riscv64 emitter, no cross-execution smoke
test for aarch64, and `native_aot` is still x86-64 only.)
Actual gates: [2026-10-16 IR/modules logs](gate-logs/2026-10-16-ir-modules/).

## The phase-1 seam and the Sayanox front end (`SX_DEFS_DUMP`, 2026-10-23)

`SX_EMIT_LOG`, `SX_ENCODE_LOG` and `SX_LINK_DUMP` all record the *back* half
of the backend. `SX_DEFS_DUMP=<dir>` records the front: it writes

```
<dir>/expand.sa   the source after every `use` splice, byte for byte
<dir>/defs.txt    the struct, generic-struct, function and global tables
```

between `collect_defs()` and `infer()`, and changes nothing else — the image
and every diagnostic are identical with and without it, which
`./sx target test-native-sxdefs` checks before it compares anything.

```
; native_aot phase 1
structs 1
struct 0 Point nf=2
  field 0 x kind=-1 sid=-1
  field 1 y kind=-1 sid=-1
gstructs 1
gstruct 0 Box np=1 nf=1
  tparam 0 T
  gfield 0 v
fns 1
fn 0 pick nparam=2 gen=1 ntp=2 rk=0 rtp=0
  param 0 a k=0 tp=0
  param 1 b k=0 tp=1
  ftparam 0 T
  ftparam 1 U
globals 2
glob 0 count kind=-1 sid=-1
glob 1 here kind=3 sid=0
```

The kinds are `0` num, `1` str, `2` list, `3` struct and `-1` unknown. The
dump is taken *before* inference on purpose: every field kind is `-1` there,
and an unannotated global is `-1` too, because filling them is phase 2's job.
`tp=` is the index of the type parameter a signature named, `sid=` the struct
identity an annotation resolved to.

`tools/sxdefs.sa` reproduces both files from the same input path — it is the
Sayanox port of `expand_use()` and `collect_defs()` — and the gate also
requires it to refuse what C refuses with the same words
([ALL_SAYANOX_PHASE.md](ALL_SAYANOX_PHASE.md), Phase D step 5).

```sh
SX_DEFS_DUMP=/tmp/d ./selfhost/native_aot in.sa out.elf   # C's phase 1
./tools/sxdefs in.sa expand /tmp/d/sx.expand              # Sayanox's
./tools/sxdefs in.sa defs   /tmp/d/sx.defs
cmp /tmp/d/expand.sa /tmp/d/sx.expand && cmp /tmp/d/defs.txt /tmp/d/sx.defs
```

## The image seam and the Sayanox linker (`SX_LINK_DUMP`, 2026-10-20)

`SX_EMIT_LOG` records the instructions the emit tree asks the encoder for.
`SX_LINK_DUMP=<dir>` is the same idea one stage later, at the finished image:
it dumps exactly the inputs of `write_elf()`, so the ELF image writer and the
rel32 linker can be rewritten in Sayanox against a pinned contract instead of
against the C source.

| file | contents |
|---|---|
| `code.bin` | the emitted machine code, `cn` bytes |
| `data.bin` | the data segment, `dn` bytes |
| `patch.bin` | `npc+npr` 16-byte records: rel32 site, then its resolved target, both little-endian u64 offsets inside the image |
| `meta.txt` | `npc npr cn dn` — the call records come first, and their count is the one thing a reader cannot recover from `patch.bin` |

Like the instruction log, it is off by default and changes no emitted byte;
`./sx target test-native-sxlink` compiles every fixture twice, with and without the
variable, and `cmp`s the two executables.

`tools/sxlink.sa` is the consumer:

```sh
./sx tool sxlink
./selfhost/native_aot in.sa out.elf                       # current native pipeline image
SX_LINK_DUMP=/tmp/d ./selfhost/native_aot in.sa out.elf   # plus the dump
./tools/sxlink out.elf /tmp/d sx.elf                      # the Sayanox-linked image
cmp out.elf sx.elf                                        # identical
```

It writes the ELF header, the three program headers, the page rounding, the
padding, the collector's heap cursor (`OFF_CUR`/`OFF_END`) and every rel32
fixup, using nothing but `push`, `xs[i] = v`, `len`, `%`, `shr`, `bit_and`,
`write_bytes` and `read_bytes`. It needs `read_bytes` — added the same day —
because `read_file` returns a C string and an ELF image is mostly NUL bytes and
page padding.

### What the linker is not

* It does not resolve names. `native_aot` still turns a `make` name or a
  builtin name into a code offset, so `patch.bin` arrives with its targets
  resolved; `sxlink` turns offsets into bytes.
* It does not choose the layout from nothing either — the segment sizes are
  `len(code.bin)` and `len(data.bin)`, and the page arithmetic is recomputed
  from them, but the fixture layout it is compared against is the one
  `write_elf()` uses.
* The standalone replay command is not a second complete compiler. The current
  producer is already the Sayanox native pipeline (`selfhost/native_aot.sa`
  and `tools/sxlink_lib.sa`), not the retired C `write_elf()`. The earlier
  pre-cutover ordering limitation was resolved by the all-Sayanox migration;
  it is not a remaining producer-replacement task.
* It is not a second backend and not a second ISA. For the native subset
  there is still exactly one executable target: x86-64 Linux ELF. (The
  separate i386 backend added on 2026-10-23 compiles a documented integer
  subset and shares no code with this seam — [NATIVE32.md](NATIVE32.md).)

## The encoder seam and the Sayanox encoder (`SX_ENCODE_LOG`, 2026-10-21)

`SX_EMIT_LOG` records what the emit tree *asks for*; `SX_LINK_DUMP` records the
finished image. Neither one is enough to rewrite the encoder itself: the
instruction list is written for a reader, and it loses exactly the choices an
encoder makes. `add %rax,%rbx` does not say whether the opcode byte is `0x01` or
`0x03`; `mov [r12+rcx*8-16],%rax` does not say whether the displacement cost one
byte or four, nor where the SIB byte went. The jump helpers `J_cc`/`J_mp`, which
the phase-4 runtime uses, do not appear in the instruction list at all.

`SX_ENCODE_LOG=<path>` records the encoder's **own calls** instead — one line per
primitive, the primitive's name and the integer arguments it was handed — and,
because `e1()` is the only function that appends a byte to `code`, one `b
<byte>` line for every byte emitted:

```
; native_aot encode log for examples/native_hello.sa
lea_r12_data
mv_r64m 0 4 -1 0 0
mv_m64 12 -1 0 16 0
...
b 73
b 137
b 69
```

| rule | why |
|---|---|
| one line per record, single spaces, decimal integers | it is read by `tools/sxencode.sa`, which has no number parser beyond `sx_index` |
| `b <byte>` after each primitive's record | the *encoder's* bytes for that same call, so the replay can check itself |
| `;` lines are headers, not records | the log is also read by people |
| 64-bit immediates as two 32-bit halves, hi then lo | a Sayanox number is a C double: exact below 2^53, and `0x3ff0000000000000` is not |
| `L_new <id>` carries the id | the runtime helpers reset `nlbl` to 0 before each one, so ids are handed out again |
| `raw_patch32 <at> <value>` | a rel32 the runtime stubs patch by hand over their own byte sequence; the value is stored, because those bytes are copied rather than encoded |

Like the other two seams it is off by default and changes no emitted byte;
`./sx target test-native-sxencode` compiles every fixture twice, with and without the
variable, and `cmp`s the two executables.

`tools/sxencode.sa` is the consumer:

```sh
./sx tool sxencode
SX_ENCODE_LOG=/tmp/e.log SX_LINK_DUMP=/tmp/d ./selfhost/native_aot in.sa out.elf
./tools/sxencode /tmp/e.log /tmp/d/code.bin /tmp/sx/rebuilt.bin
cmp /tmp/d/code.bin /tmp/sx/rebuilt.bin      # identical
```

It implements the same primitives — `rexb`, `emit_modrm`, the `mov`/`lea`/arith/
shift/SSE2 helpers, the label table and the four patch forms — out of `push`,
`xs[i] = v`, `len`, `bit_and`, `bit_or`, `shl`, `shr`, `write_bytes` and
`read_bytes`, and it rebuilds `code.bin` byte for byte. It carries the label
table's own caps (`MAXLBL` 96, 24 references each) and refuses a stream that
exceeds them, and it refuses a record it does not implement instead of half
applying it.

### What the replay checks, and what it does not

* Every named record is followed by the bytes C wrote for that same call. The
  replay encodes the record, then compares its own output with those bytes and
  stops on the first disagreement — a wrong ModRM or a displacement that should
  have been `disp8` fails at the instruction, not in a later `cmp`.
* The final file is compared with `code.bin`, so bytes the runtime writes by
  hand are covered too. Those come through as `b` records that no named record
  claimed; they are copied, not encoded, because the C source writes them as
  literals. That is the honest boundary: the *encoder* is Sayanox, the
  hand-written runtime stubs are transported.
* Since 2026-10-24 (Phase D Step 10), `selfhost/native_aot.sa` + `tools/sxenc_lib.sa`
  IS the sole producer of `./selfhost/native_aot` (`selfhost/native_aot.c` is deleted).
* **Portable IR virtual machine (`tools/sxirexec.sa`, 2026-10-24):**
  `tools/sxirexec` loads the portable IR emitted by `tools/emit_to_ir --strict --source-offsets`
  plus `data.bin` (`SX_LINK_DUMP`) and executes the program on a pure-Sayanox register/stack/heap
  VM with zero host x86-64 ELF execution (`compile-and-run` deletes the ELF binary before VM
  execution). `./sx target test-ir-exec` verifies 4-way parity (`seed-min == gen2 == native_aot == sxirexec`)
  across SHA-256/HMAC-SHA256 (`stdlib_crypto_test.sa`), `stdlib_json_write_test.sa`,
  `stdlib_growth_test.sa`, and `native_ir_log_test.sa`, plus Stage-2 struct-typed functions and
  `${id}` string interpolation.
