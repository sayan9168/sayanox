# 2026-10-21 — `SX_ENCODE_LOG`, and the encoder becomes Sayanox

On branch `arena/0c0d6e74-sayanox`. Every log in this directory is the actual
command output; `status.txt` records each gate's exit status.

Phase D step 4. Steps 1–3 gave the language a byte buffer, its reader, and the
backend's ELF image writer with its rel32 linker. What was still C is the part
that decides the actual machine-code bytes: the ~50 encoder primitives in
`selfhost/native_aot.c` that every `mov`, `lea`, `add`, `setcc`, `jcc` and
`jmp` goes through. They are now a Sayanox program, proved equal to the C ones
byte for byte on the whole code segment rather than on single instructions.

## What changed

| file | before | after | what |
|---|---:|---:|---|
| `selfhost/native_aot.c` | 4,415 lines | 4,498 lines | the encode recorder (`elog`), one record per primitive call, and `b` records for raw bytes |
| `tools/sxencode.sa` | — | 1,159 lines | the same primitives in Sayanox, replayed against that log |
| `Makefile` | 5,002 lines | 5,112 lines | `tools/sxencode` rule, `test-native-sxencode`, `native-test` dependency |
| `.gitignore` | — | one line | the built `tools/sxencode` binary |

The C file did not shrink and is not claimed to: it gained the seam, the same
way `link_seam()` grew it in step 3. What left the C file is the *decision*
about bytes, and it left as a program a gate can run.

## `SX_ENCODE_LOG=<path>` — the seam

`SX_EMIT_LOG` (2026-10-13) records the instruction list in assembly form, which
is what a human reads and what `tools/emit_to_ir.sa` translates. For an
encoder that list is lossy in exactly the places an encoder has to decide:

* `add %rax,%rbx` does not say whether the opcode is `0x01` or `0x03`;
* `mov [r12+rcx*8-16],%rax` does not say whether the displacement cost one
  byte or four, nor where the SIB byte went;
* `J_cc`/`J_mp`, which the phase-4 runtime uses for its own control flow, are
  not in the instruction list at all.

So the new recorder writes the encoder's **own calls**: one line per primitive,
its name and the integer arguments it was handed, and one `b <byte>` line for
every byte `e1()` appends.

| group | records | what the Sayanox side has to get right |
|---|---|---|
| register only | `mv_rr`, `bin_rr`, `fm7`, `test_rr`, `xor_rr`, `incdec_r`, `push_r`, `pop_r`, `setcc`, `sar_imm`, `shl_imm`, `shr_imm`, `movq_xr`, `movq_rx`, `addsd`, `mulsd`, `subsd`, `divsd`, `ucomisd`, `cvtsi2sd`, `cvttsd2si`, `cvtsd2si` | register ids in the C signature's order, and which prefix each one forces |
| memory operand | `mv_m64`, `mv_r64m`, `lea_rm`, `mov_imm8m`, `mvz_rm` | base, index, scale, disp; `-1` means absent, and disp `0` is still forced to a 4-byte field where C forces it |
| immediate | `mov_imm64` (high 32 bits then low), `bin_imm8`, `bin_imm32` | a Sayanox number is a double, exact only below 2^53, so 64-bit values travel as halves |
| fixup | `patch_imm32`, `erel32`, `erel32j`, `raw_patch32` | absolute offsets and resolved values, never a name |
| label | `L_new`, `L_bind`, `J_cc`, `J_mp` | a `L_new` record carries its id, because the runtime resets `nlbl = 0` before each helper |
| slot / raw byte | `sub_rsp_slot`, `jmp5_slot`, `leave_ret`, `stal_rdi`, `stb_rdi`, `lea_r12_data`, `call_p`, `movzx_al_to_rax`, `b` | the four slot-returning records do not log their return: the replay's own cursor must land on the offset C used, or the following `patch_imm32` writes to the wrong place |

The authority is `op_id` in `tools/sxencode.sa` (50 names, ids 1-50); the gate
refuses a stream whose name is not in it and requires the fixture set to
exercise every name in it, so the two lists cannot drift apart unnoticed.

Rules, so a reader can check them:

* one record per line, fields separated by one space, decimal integers;
* a `;` line is a header, not a record;
* a record appears **before** the bytes it describes, exactly where the
  function is called, so stream order is code order;
* the recorder only reads its arguments — it does not touch `code` or `cn`, so
  the emitted ELF is byte-identical with and without `SX_ENCODE_LOG`, which the
  gate asserts;
* the `b` records are the recorder's own copy of what the calls produced, so
  every encoded byte is checked twice: once against the Sayanox encoding, and
  once against the recorder's byte.

The last two points are what make the stream self-checking rather than a
transcript. The replay encodes a record, then demands the `b` lines that follow
it: a wrong opcode, a wrong ModRM or a wrong displacement fails at that
instruction, with the record name in the message.

## The gate

`make test-native-sxencode`, part of `make native-test`:

1. five fixtures are compiled twice, with and without `SX_ENCODE_LOG`, and the
   two ELF images must be identical (the recorder is inert);
2. `tools/sxencode` replays each log and must reproduce `code.bin` —
   4,912 to 15,380 bytes of code per fixture — byte for byte;
3. the tool's report echoes the code size, the label count and the fixup count
   per fixture, so a silent change in either table shows up in the log;
4. the name list and the encoding list must have the same length (50 records),
   and the fixture set must exercise every one of them;
5. a missing log, a `code.bin` of the wrong length and an unknown record name
   are clear errors, not silent successes.

The five fixtures are `sxencode_hello` (a bare program), the instruction-list
fixture (`native_ir_log_test`), a boolean-argument function (which is what
emits `jmp5_slot`), a string-ordering loop, and the stdlib growth fixture (the
one that emits `sar_imm` and `patch_imm32`).

## What this does not claim

* `native_aot` still drives its own encoder to produce the executables the
  gates run. Making `sxencode` the producer would make the native backend's
  output path depend on gen2 — a bootstrap ordering change, the same reason
  `sxlink` is not wired in either.
* the bytes the phase-4 runtime writes by hand (the 856-line stub block and the
  collector, written as `e1(...)` literals) arrive as raw `b` records and are
  copied, not encoded. They are inside the compared range, but they are not
  ported.
* the stream carries label ids and absolute patch offsets. Turning a `make` or
  builtin name into an offset is still the C frontend's job.
* the scanner, parser, type inference, emit tree, runtime stubs and collector
  are still C, and `native_aot.c`'s row stays in the `all-sayanox` inventory
  with its line count.
