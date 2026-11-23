# 2026-11-23 — AArch64 ISA coverage in `sxisaexec`, and file I/O in `native32`

Branch `arena/c33f9f7c-sayanox`, based on `main` at `07e47e7`. Two halves, one
because the second only became checkable once the emulator could execute it: the
compiler gained `read_file`/`write_file` lowering for i386, AArch64 and RV64IM,
and the emulator gained the AArch64 decoders that the resulting images need.

## Half one: `read_file` / `write_file` in `tools/native32.sa`

The published backends reach these two builtins through the C runtime; `native32`
has no runtime, so it now lowers them into the target's own Linux syscall ABI.
Each image gets one shared routine per builtin, placed after the `make` bodies and
reached by `call`, exactly like the shared `string_eq` routine. Arguments and
results travel in one lazily reserved 4129-byte data block, so no call site needs a
frame and a program that never names a builtin pays nothing:

| offset | field |
|---|---|
| `+0`, `+4` | path pointer, path length (the path's NUL is pooled with the literal) |
| `+8`, `+12` | text pointer, text length |
| `+16` | the descriptor `openat` returned |
| `+20` | the count `write` or `read` reported |
| `+28` | what `close` reported |
| `+32..4127` | the 4096-byte read buffer |
| `+4128` | one newline byte, so `show` of a full or empty result stays inside the block |

`write_file` is `openat(AT_FDCWD, path, O_WRONLY|O_CREAT|O_TRUNC, 0644)`, one
`write`, one `close`, and answers `(count == len) && (close == 0)`. `read_file` is
`openat`, one bounded `read` of 4096 bytes, `close`, then a walk that stops at the
first NUL — the same span rule every other string value in the dialect follows —
and a negative count (a failed open) stops the walk at once, so an unreadable path
gives `""`. Addresses inside the block are baked into *code* immediates and never
stored into the data image, so the arch-neutral data segment rule (R14) holds.

Two shapes are refused rather than approximated, because the target cannot express
them:

```
line N: read_file and write_file take a string-literal path in native32, because the NUL the syscall stops at has to be pooled with it
line N: write_file's text must be a string, not a number
```

Fixture `selfhost/native32_tests/file_io.sa` (a write, a read-back, a length, a
`concat` rewrite, a read-back, then a write and a read of a path under a directory
that never exists) is pinned by `file_io.want` and runs on all six execution paths,
with reviewed `golden/file_io.arm64.elf` and `golden/file_io.riscv64.elf` and the
i386 image size pinned at 12735 bytes; the two refusals live in
`selfhost/native32_tests/refuse/`.

## Half two: AArch64 decoders in `tools/sxisaexec.sa`

Against `main` this is mostly *new* decoders and a few *wrong* ones. The six probe
images at the bottom of this file say which is which, run against the `main` build:
five of them stop at the first word `main` does not decode, with
`illegal or unsupported instruction word` and exit 1 — `LSR`-as-`UBFM` (shift), a
64-bit `CSEL` (csel), `LDRH` (mem), `FMOV x10,d1` (fp) and `ADRP` (ctrl) — while the
multiply image runs to completion and reports six of nine probes wrong. So the
forms the compiler emits were either refused or, where `main` did decode them,
sometimes wrong; a wrong answer is the reason the probes are pinned one instruction
at a time rather than as another whole-program fixture.

Added:

* `SBFM`/`UBFM`/`BFM`/`BFXIL` and `EXTR` (block 6b): the field is extracted, and for
  the wrapping form (`imms < immr`, which is what `LSL`/`ASR` decode to) it has to
  be clipped, then sign-extended, then shifted up to bit `regsize - immr` — in that
  order, or the clip drops the value. `EXTR` carries its own 6-bit amount at 15:10,
  which includes the bit the bit-field `imms` decode excludes, and takes `Rn` as the
  high half of the 128-bit pair: `extr w10, w4, w4, #8` is the rotate `0xEFDEADBE`.
* `BFM` writes the field to bit 0 and overwrites the whole destination; the wrapping
  form writes every bit. A merge with the old `Rd` — the first reading of the rule —
  is what `QEMU` disproved on `bfm x10, x1, #4, #12`.
* The `CSEL`/`CSINC`/`CSINV`/`CSNEG` group at both widths, with `CINC`/`CNEG`/`CSET`/
  `CSETM` falling out of it: all four take `Rn` on the true arm and transform `Rm`
  (+1, `~`, negate) on the false one. `main` matched a 32-bit `CSINC` shape (and
  swallowed `CSETM` into it, answering `+1` where the architecture says all ones),
  so `csel`, `csinv`, `csneg` and every `x`-register form faulted. Only a probe with
  distinct `Rn` and `Rm` pins the arm choice down: every alias repeats one register
  and spells the inverted condition, which is why the compiler's own `cset` output
  could not have found any of this.
* `FMOV` between the general and FP registers at both widths (`bit 16` picks the
  direction, `Rd` names the FP register on the general-to-FP form), and
  `FCVTZS`/`FCVTZU` for `Wd`/`Xd` against `Sn`/`Dn` — `main` had the `W`-and-`D`
  shape only, with no saturation, where a negative under `FCVTZU` becomes 0 and
  `2^64` becomes all ones.
* `LDRH`/`LDRSH`/`LDRSB`/`LDRSW` at both widths, next to the loads and stores `main`
  already scaled correctly by access size (`uimm12` counts accesses, not bytes).
* `BR`/`BLR`/`RET` and `ADR`/`ADRP`, without which the branch-shaped probes below
  cannot be written at all.

Fixed:

* `a64_mul`, the pair-domain multiply the 3-source block now uses. `main`
  multiplied the two low halves with `mul32_u` and wrote the result through
  `set_arm_w`, so a 64-bit `MADD`/`MSUB` lost everything above 2^32, the accumulator
  kept only its low half, and `SMADDL`/`UMADDL`/`SMSUBL`/`UMSUBL` were not
  distinguished from it at all. The trap for a pair-domain rewrite is its own carry:
  folding `s1`'s carry out of bit 63 back into the high word (with two of the top
  column's four products missing) is what made the first version answer
  `(-2) * (-4)` = `00020000_00000008`; the shipped version keeps four limbs per
  operand, all four products in the top column, and drops the carry. The forms that
  look right under the shortcut are right only because one operand's high limbs are
  zero — which is exactly what `UMADDL` guarantees and `SMADDL` does not.
* `LDR S` filled `V<n><63:32>` with ones (`f_hi[rd] = 4294967295` in `main`); a
  single-precision write zeroes it. `t_arm_fp_elf` stayed green through it because
  the fixture never reads that half back.
* The unallocated shapes inside the groups above (the 3-source base, bit-field
  immediates out of range for the width, `EXTR` with o1 set) now refuse. `main`
  executed `0x1B800000` as if it were a valid instruction. A word that matches no
  decoder at all was already refused and still is.

## How this was checked

Every probe is one instruction with its own seeded registers, wrapped in the
compare-and-accumulate idiom the emulator already uses for its other fixtures: the
result lands in `x10`, an expected value in `x11`, and `w20` counts mismatches, so
the image's exit status *is* the number of failing probes. 71 probes in six images
(`shift`, `csel`, `mul`, `mem`, `fp`, `ctrl`). Each probe was then run three ways —
the emulator, QEMU user-mode ARM64 (Unicorn, fresh CPU per probe), and a hand-written
expectation — and any disagreement was settled by the emulator-vs-QEMU column, not
by the reference model, which is where several hand-written expectations turned out
to be the wrong ones (`csetm x10,eq`, three `csel` condition codes, `bfm`). The
generator, the reference model and the QEMU driver were scratch tooling and are not
part of the build; what is committed is the resulting image builders in
`tools/sxisaexec_test.sa` (`t_arm_isa_shift_elf()` … `t_arm_isa_ctrl_elf()`) and the
one gate line that runs them.

The `ctrl` image is the one that needs real addresses: `BR` and `BLR` jump to
computed targets, so its jump slots are reserved at a fixed four words each
(`MOVZ` + three `MOVK`) and patched after the layout is known. Both checks are
poison-shaped — a `BR` that does not happen runs an `add w20, w20, w20` it was
 supposed to skip, and `w22` has to arrive at the value only the callee writes.

Negative controls: each deliberate break of a decoder makes exactly its own image
fail, which is what keeps the six images from being a set of tests that pass by
construction.

| break | shift | csel | mul | mem | fp | ctrl |
|---|---|---|---|---|---|---|
| CSEL true-arm test inverted | 0 | **16** | 0 | 0 | 0 | 0 |
| BFM keeps the destination's top bits | **1** | 0 | 0 | 0 | 0 | 0 |
| multiply re-folds the bit-64 carry | 0 | 0 | **2** | 0 | 0 | 0 |
| EXTR halves swapped | **1** | 0 | 0 | 0 | 0 | 0 |
| `uimm12` no longer scaled | 0 | 0 | 0 | **3** | 0 | 0 |
| FMOV directions swapped | 0 | 0 | 0 | 0 | **8** | 0 |
| `BLR` reads the wrong bit | 0 | 0 | 0 | 0 | 0 | **1** |

## What it exposed about the compiler

The corrected CSEL rule raised a question about `tools/native32.sa`, which hand
encodes `cset` for the file-I/O result check: if the decoder's arm rule moved, did
the emitted words and the two AArch64 goldens have to move with it? They did not.
`main` already computed `CSINC` as "Rn on the true arm, Rm + 1 on the false one" —
the same rule this branch generalises to the other three operations and to `sf = 1`
— so the `cset` words behave identically before and after, and nothing was
re-encodin. What is verified here is the end-to-end answer, which is what matters:
`selfhost/native32_tests/golden/file_io.arm64.elf` run under this emulator prints
exactly `file_io.want`, including the `1` that a successful write must report, and
`test-native-arm64` passes with the goldens unchanged. (`LDR S`'s upper half is the
opposite case: `main` filled it with ones, so the pre-existing
`t_arm_fp_elf` fixture had pinned the *wrong* answer for a single-precision load --
it sets no register the fixture reads, which is why it stayed green.)

## Gates run

```
./sx target test-sxisaexec      [OK]  (six-way parity, safety negatives, syscall
                                     probes, FP probes, and now the ISA probes)
./sx target test-native32       [OK]
./sx target test-native-arm64   [OK]
./sx target test-native-riscv64 [OK]
./sx migration                  Sayanox driver target coverage: 241 / 241
./sx doctor                     [OK] sxbuild doctor passed
```

`test-native-arm64` ran cold in 6m51s and incrementally in about 40s; the other
three gates are in the same range. Every emulator build above went through
`SXBUILD_VIA_C=1 ./sx tool sxisaexec` first, which is the stricter path: it compiles
the Sayanox source to C, and `main`'s `tools/sxisaexec.sa` does not survive it (two
registers were held inside an `is_sub_r` branch and read after it, which the C
backend refuses and the self-hosted front end tolerated).

## Still open (tracked as R20)

* The divide is still 32-bit: block 6 reads `Rn`/`Rm` low halves only, divides with
  `div_u32`/`div_s32_arm` and writes through `set_arm_w`, so `UDIV`/`SDIV` with
  `sf = 1` cannot produce a quotient above 2^32 and leave the high half zero. The
  probes do not pretend otherwise -- no `udiv`/`sdiv` case is in the six images,
  and adding one needs a pair-domain divide first.
* RV64 still has no 64-bit `mul`/`mulh`/`div`/`rem` (only `mulw`, `divuw`,
  `remuw`), so the RV64 twin of these probe images cannot express the same ground.
* The scalar FP probes pin loads, `FMOV` and `FCVTZS`/`FCVTZU` per case;
  `FADD`/`FSUB`/`FDIV` keep the pre-existing whole-image fixture, where one wrong
  result can hide behind another.
* Per-instruction FP *arithmetic* stays an emulator property: `native32` lowers no
  FP expressions, which is R02 stage (3).

Refusal behavior was checked directly, because "unsupported" and "silently skipped"
look the same from the outside. Patching word 0 of a fixture image with each of
`UDF #0` (0), `0xFFFFFFFF`, `MRS x10, NZCV`, `BRK #0`, `DSB ISH`, `LDXR x10,[x7]`,
`STP x29,x30,(sp,#-16)!`, `LDP x29,x30,(sp),#16`, `ORR v0.16b,...`, `FCMP d0,d1`,
`FMADD d0,d1,d2,d3` and `RBIT x10,x7` gives exit 1 with an
`illegal or unsupported instruction word` diagnostic in every case on this branch,
and the same on `main`. Two things differ from `main`: the unallocated
shapes *inside* groups the emulator does decode (`0x1B800000`, an undefined
3-source base) now answer `AArch64 unallocated 3-source encoding` instead of
executing as if the word were valid, and the words the compiler actually emits are
no longer in the refused set at all. `SDIV x10,x7,x8` is accepted on both, which is
the 32-bit-divide limitation above, not a missing refusal.

