# 2026-11-24 — `SMULH`/`UMULH` and the RV64 64-bit M extension in `sxisaexec`

Branch `arena/9a8509bd-sayanox`, based on `main` at `072655c`. This closes item (4)
of R20 (the AArch64 3-source group) and, in the same fixture, the RV64 half of the
M extension, which had no coverage at all.

## What was claimed, in the end

- AArch64 `SMULH` / `UMULH` decode to bits 127:64 of the 128-bit product, for all
  four sign combinations, with `sf = 1` only.
- The five unallocated shapes around them are refused with a line-free but
  named diagnostic and a non-zero exit, not answered.
- RV64 `MULH` / `MULHSU` / `MULHU` / `MUL` and `DIV` / `DIVU` / `REM` / `REMU`
  produce the architecturally correct 64-bit answer, including the RV-vs-AArch64
  differences at a zero divisor and at `INT64_MIN / -1`.

## The original framing was superseded, and that matters

R20 item 4 was written as "refuse it". That was wrong, and the probe said so. The
two words are real instructions that a compiler emits; refusing them would have
turned a silently wrong answer into a refusal, which is better but still not the
answer. The increment is therefore a **decode-and-test** change, not a
refusal-matrix change. **No refusal-matrix count moves**, and this log should not
be read as one that did.

What the gap actually was:

- Before this change `mid5 == 27` tested bit **23** (`u_m`) to pick the wide
  forms. `SMULH` is `op31 = 010` and `UMULH` is `op31 = 110`, so bit 23 is clear
  for the first and set for the second. The consequences were asymmetric:
  - `UMULH` fell into the `l_m == 0 && u_m == 1` branch and was *refused* as an
    unallocated 3-source encoding. Annoying, but honest.
  - `SMULH` fell through to the `SMADDL` path, which multiplies the two 32-bit
    halves, adds `Ra` (here `xzr`) and writes bits 63:0. The architecture asks
    for bits 127:64. The image therefore **ran green with the wrong number**.
- The discriminator is bit **22**. It is clear for `op31 = 000/001/101` (MADD,
  SMADDL/SMSUBL, UMADDL/UMSUBL) and set for `010/011/110/111`
  (SMULH, unallocated, UMULH, unallocated). `Ra == 11111` is *not* a sufficient
  discriminator on its own, because `madd x10, x24, x25, xzr` is a perfectly
  legal MADD and must keep its old answer.
- `op31 = 100` is the trap in the other direction: bit 22 is clear, bit 23 is
  set, bit 21 is clear, and there is no such instruction. A decoder that switches
  on bit 22 alone silently answers it as ... something. It is refused explicitly,
  by a clause that tests bit 21 as well so `op31 = 101` (UMADDL) survives.

The RV64 side had no fixture row at all before this change. `rv_m64` and
`rv_div64` did not exist; every 64-bit M word was refused. Two of the three
defects found while writing the test were in code written for this increment, not
in `main` — see the negative controls.

## Files changed

| File | What |
| --- | --- |
| `tools/sxisaexec.sa` | New pair-domain helpers `a64_mulh`, `a64_mul128` (already present), `rv_m64`, `rv_div64`. Block 5 (`mid5 == 27`) rewritten around bit 22. RV64 `op == 51` split into the `f3 <= 3` multiply group and the `f3 >= 4` divide group. |
| `tools/sxisaexec_test.sa` | New block before the AArch64 divide probe: constant builders (`tb_word`, `tb_mov64_abc`, `tb_mov64_chunks`, `tb_rv_r`), the multiply model (`tb_mulh_model`, `tb_mulh_row`), the two images (`tb_arm_mulh_elf`, `tb_rv_mul_elf`) and the five-row unallocated control. Wired into `test_arm64_isa_coverage(dir)` and `test_negative_faults(dir)`. |
| `docs/full-language-v1.sha256` | Rows 165 / 166 re-pinned. |
| `bootstrap/sx.sha256` | Row 60 (`docs/full-language-v1.sha256` itself) re-pinned, because the manifest is pinned by hash in the bootstrap set. |
| `docs/gate-logs/2026-11-24-aarch64-multiply-high.md` | This file. |
| `README.md`, `docs/STATUS.md` | Status rows. |

## Gate

`./sx target test-sxisaexec` — the one new gate is an extension of the existing
target, not a new `./sx target` name, because `tools/sxtargets_test.sa` pins
`241 / 241`.

## Expectation counts per fixture

- `isa_mulh.arm64.elf` — **7 rows**, each comparing a 64-bit result against a
  4-limb expectation:
  1. `UMULH` negative × positive
  2. `SMULH` negative × positive
  3. `SMULH` positive × negative (only `Rm` negative)
  4. `UMULH` positive × negative (same operands as 3)
  5. `SMULH` negative × negative (both corrections, positive answer)
  6. `UMULH` `2^63 × 16`
  7. `UMULH` `0 × 0`
- `isa_rvmul.riscv64.elf` — **4 comparison rows** (`tb_rv_compare` × 4) covering
  `MULH`, `MULHU`, `MUL`, `DIVU`, plus the operand construction for both 64-bit
  inputs.
- Unallocated control — **5 images** (`unalloc3_0..4`), one per refused shape,
  each ending in a real `exit(0)` trailer so the only way to pass is a refusal.

The failure counter is the exit status, so a failing run names the row rather than
only reporting that something is wrong.

## Negative controls

Each was applied to `tools/sxisaexec.sa`, rebuilt with
`./sx tool sxisaexec /tmp/ncb` (~1 s), installed, run against the fixture, and the
module restored byte-exact (`cmp` clean).

| # | Deliberate break | Caught by | Observed |
| --- | --- | --- | --- |
| NC1 | `dneg = 0` — drop the `Rm` correction term | `isa_mulh.arm64.elf` row 3 (`SMULH` positive × negative) | exit 2 |
| NC2 | `nneg = 0` — drop the `Rn` correction term | rows 2 and 5 | exit 2 |
| NC3 | `sgn = 0` — evaluate `SMULH` as `UMULH` | rows 2, 3, 5 | exit 3 |
| NC4 | delete the `op31 = 100` refusal | `unalloc3_4.arm64.elf` | exits 0 under the break, 1 when correct |
| NC5 | `f3 == 1` also takes the low-half path in RV64 | `isa_rvmul.riscv64.elf` (`MULH`) | exit 1 |
| NC6 | restore the original `out[2] = h[1]` transposition | RV64 high-half rows | exit 2 |
| NC7 | restore `signd = f3 % 2` (DIVU read as signed) | RV64 `DIVU` row | exit 1 |

NC1–NC3 were run twice, once before and once after the fixture gained the
positive × negative rows. Before those rows existed **NC1 did not fire**: every
operand pair in the fixture had `Rm` positive, so the `dneg` term was never
exercised and the control was a claim, not coverage. The rows were added because
the control failed, which is the only reason to trust it now.

NC4 likewise did not fire at first, twice for two different reasons:

1. The five control images did not include `op31 = 100` at all — the shape the
   clause exists for. A fifth row was added.
2. Even with the row present, the images ended immediately after the bad word, so
   a decoder that *accepted* it ran off the end onto a zero word, faulted, and
   also exited 1. The row could not distinguish "refused" from "accepted then
   crashed". Each image now ends with `mov w0,#0; mov w8,#93; svc #0`, so
   acceptance is observable as exit 0.

NC5's first run also refused to fire, and the reason was worse: `tb_rv_mul_elf`
never moved the failure counter into `a0` before the `exit` syscall, so the RV
image exited with whatever `a0` happened to hold — always 0. The entire RV half of
the probe was unfalsifiable until that was fixed. This is exactly the failure mode
the negative-control rule exists to catch, and it caught it.

## Bugs the fixture found (not introduced by the fixture)

Three defects, all found by making the test able to fail:

1. **`rv_m64` transposed the high half** (`out[2] = h[1]`, `out[3] = h[0]`).
   `a64_mulh` fills `h[0]` with the low 32 bits of the high half and `h[1]` with
   the high 32 bits, so every RV64 `MULH`/`MULHU`/`MULHSU` answer had its two
   halves swapped. This was new code in this increment and never shipped.
2. **`signd` was inverted** for the RV64 divide group. `funct3` bit 0 selects the
   *unsigned* form, so `signd = 1 - f3 % 2`; reading `f3 % 2` made `DIVU`/`REMU`
   signed. New code, never shipped.
3. **`tb_mov64_chunks` started from `LUI`** (`c5 << 12`) and then shifted 11 five
   times, putting the top chunk at bit 67 and silently dropping bits 63:56; the
   operand came out `0x709abc56781234` instead of `0xdef09abc56781234`. Every row
   of the RV probe disagreed for a while, which is what made it findable. This was
   a fixture bug, not an emulator bug.

The last one is worth recording because the first two were *also* invisible while
it was present: the fixture was wrong, so all four rows failed, and the emulator
defects hid inside that noise.

## Honest limits

- This is a bounded slice: the AArch64 3-source multiply group and the RV64
  64-bit integer M extension. It is not "AArch64 support" and not "RISC-V M".
  Single-width `MULW`/`DIVW`/`REMUW` (RV64 `op`-32, `opcode 59`) are **not**
  covered here; the log does not claim them.
- The RV64 rows cover one operand pair plus `DIVU`. `MULHSU`, `DIV`, `REM` and
  `REMU` share the same code paths as rows that are exercised, but no row names
  them directly. That is a gap, recorded rather than papered over.
- `SMULH`'s `Ra != 11111` refusal is pinned as a control image; `SMULH` with
  `sf = 0` is refused by the existing wide-form clause and is not given its own
  row.
- The expected limbs were derived by hand from the architectural definition, and
  cross-checked against a host `python3` computation during development. The
  `python3` step sets no expectation and no gate needs it; the committed
  expectation lives in `tools/sxisaexec_test.sa` and nothing regenerates it at
  gate time.
- `native_aot`, `sxc_native`, `sxirexec` and `i386` are untouched by this
  increment: it is entirely inside the ARM/RV emulator, which no other lane uses.
- No independent trust proof. The bootstrap anchor was not rebuilt and no
  `compiler2 == compiler3` fixed point was re-derived here; the pins that moved
  are source hashes only (`docs/full-language-v1.sha256` rows 165/166 and its own
  hash in `bootstrap/sx.sha256`), not the entry binary.

## Exit codes

Recorded in the PR body; the full chain is listed there with the exact command
lines. `native-test` runs longer than a single 30-minute tool call on this host
and was run as a background process; its exit code is reproduced verbatim.
