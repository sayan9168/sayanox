# 2026-11-23 — 64-bit `UDIV`/`SDIV` in `sxisaexec`, and a divide probe that can fail

Branch `arena/d4fb1748-sayanox`, based on `main` at `0513196`. This closes item (1)
of R20: the AArch64 divide used to answer every width from the 32-bit path.

## The gap

Block 6 decoded `UDIV`/`SDIV` correctly but executed both widths the same way: it
read only `rlo[Rn]`/`rlo[Rm]`, divided with `div_u32`/`div_s32_arm`, and wrote
through `set_arm_w`. So `x10 = x24 / x25` answered with the low
half of the quotient and a zeroed high half, and a negative 64-bit quotient lost its
sign. The
word was *accepted*, not refused, which is what made it dangerous: an image that
divides at 64 bits used to run green with wrong numbers. `main` is the same way, so
this is not a regression the probes introduced -- it is the gap the probes found.

## The fix

`tools/sxisaexec.sa` grows `a64_div` and `a64_sdiv` (both in the `(lo, hi)` u32
pair domain, like every other 64-bit helper here). `a64_div` is restoring long
division, one dividend bit per iteration: `R = (R << 1) | bit i of N`, subtract the
divisor where it fits, set quotient bit `i`. Nothing above 2^53 is ever held as one
`num`, so the model survives the C-double backend. `a64_sdiv` takes magnitudes,
calls `a64_div`, and fixes up signs -- which is why the most-negative quotient needs
no clause of its own: negating 2^63 wraps back to 2^63, and dividing that by itself
unsigned gives 1, which is the architectured answer. A zero divisor leaves the quotient at zero
for both flavours, again per the architecture rather than by a special case.

Dispatch now branches on `sf`: `sf == 1` runs the pair divide and writes through
`set_arm_x`; `sf == 0` keeps `div_u32`/`div_s32_arm` and `set_arm_w`, which is
`main`'s behaviour and is still what the compiler emits, since `native32` refuses
`/` outright and never lowers a divide at all.

## A dead branch, proven dead and deleted

The first version of `a64_div` carried an explicit bit for a shift out of bit 63 and
let that bit force a subtract, on the theory that the running value `R` could reach
2^65 mid-loop. A counter build of the emulator reported `ovf=0` for every fixture,
which is not proof, so the branch was checked properly. The argument is the prefix
one: at the top of iteration `i` the value being shifted is the remainder left after
the bits above `i` were consumed, so once bit `i` is shifted in, `R` is exactly the
prefix of the dividend formed by bits 63 down to `i`, and the subtract only lowers
it. Therefore `R <= N <= 2^64 - 1` at every point and the shift cannot overflow --
the divisor's size is irrelevant to it, which is worth stating because "below the
divisor" is a true but insufficient bound. It was also measured: every operand pair
at 6, 8 and 10 bits, all 256x255 pairs at 8 bits, 200k random 12-bit pairs, and 400k
structured 64-bit pairs, with 64 random dividends times every divisor that fits --
zero firings. The branch is deleted and the comment in `tools/sxisaexec.sa` records
the bound instead of the code.

## The probe, and how it is generated

Sayanox has no hex literal and a `num` cannot hold 2^64 - 1, so the table in
`tools/sxisaexec_test.sa` spells operands as hex *text*, parsed into four 16-bit
limbs. 25 rows: 23 divides over both widths and both signs -- including `0`
divisors, `xzr` as the divisor register, the most-negative quotient, `-1` divided by
the smallest negative, and sign crossings at the 32-bit boundary -- plus two rows that check the flags survive a
divide (`cmp`, divide, `cset` of the earlier condition, because a divide must not
touch `NZCV`).

Two things make this table its own evidence rather than a list of numbers I typed:

* **An independent model, in the same file.** `t_dv_uq` recomputes each quotient by
  long division over eight base-2^16 limbs and `t_div_case` refuses the file unless
  `q * d + r == n` and `r < d` for the row, and unless the pinned expectation equals
  the model's. Writing the harness this way caught a real model bug (a W-form signed
  row took its sign from bit 63 of the masked value instead of bit 31 of the low
  half) *and* a transcription error in my own table -- the two failures are
  separate messages, which is what made each one diagnosable.
* **One generator, two shapes.** `t_div_rows(code, want)` appends every row when
  `want < 0` and row `k` alone otherwise, so the full image and the 25 single-row
  images are the same code. `t_div_table_walk` proves the rows tile the image --
  each row's bytes are found at the offset the walk predicts, and the tiling ends
  exactly where the image does -- so per-row attribution cannot be measuring a
  different program from the one the gate runs.

## Negative control

Fifteen deliberate breaks of the divide path, each built into its own emulator and
run against all 25 single-row images plus the full image. "rows catching" is the
per-row attribution; "image" is the full image's exit status, which is the number of
pinned checks the break trips -- the two columns agree for every mutant, so no break
hides in the aggregate.

| # | break | rows catching | image |
|---|---|---|---|
| m1 | `rhi = u32(rh - dhi - borrow)` drops the borrow | 20 21 22 | 3 |
| m2 | high-half quotient bit `i - 32` written as `i - 31` | 1 2 4 6 9 11 20 22 | 8 |
| m3 | `when i >= 32` narrowed to `i > 32` (bit 32 lost) | 1 2 4 6 11 20 22 | 7 |
| m4 | signed: quotient sign fix-up never applied | 10 11 13 21 | 4 |
| m5 | signed: dividend sign read from `nlo` instead of `nhi` | 10 11 | 2 |
| m6 | `sf == 1` result written through `set_arm_w` | 1 2 4 6 9 10 11 13 20 21 22 | 11 |
| m7 | `sltu64(rl, rh, dlo, dhi) == 0` inverted (never subtract) | 0 1 2 4 5 6 7 8 9 10 11 13 14 15 16 20 21 22 | 18 |
| m8 | zero-divisor guard dropped | 3 12 | 2 |
| m9 | signed: divisor magnitude not taken | 9 13 | 2 |
| m10 | low-half quotient bit `i` written as `i & 15` | 0 1 2 4 6 11 13 14 20 21 22 | 11 |
| m11 | `when sl2 < 0` never taken (borrow always 0) | 20 21 22 | 3 |
| m12 | `rlo` starts at 1 instead of 0 | 0 1 2 4 5 7 8 9 10 11 13 14 15 16 20 21 22 | 17 |
| m13 | `when sl2 < 0` loosened to `sl2 < 1` (borrow one too eager) | 0 4 9 11 | 4 |
| m14 | shift-in bit taken from `nhi` at `i - 31` | 0 1 2 4 5 6 7 8 9 10 11 13 14 20 21 22 | 16 |
| m15 | carry from the low half into `rhi` dropped | 5 7 8 10 20 21 22 | 7 |

m1 and m11 are the point of the last three rows. With 22 rows the table checked
*quotients only*, and a dropped borrow corrupts the running remainder without
changing a single quotient in that set -- both mutants ran green on all 22 rows and
on the whole image. Rows 20, 21 and 22 were then searched for among 400k structured
operand pairs (15 passes over the generator, each candidate verified against the
sign-division model and against `rhi - dhi - 1 != rhi - dhi`), and each one fires the
borrow: the counter build reports `borrow=4`, `borrow=1` and `borrow=10` for them.
Every mutant is now caught, and by rows that name it.

## Coverage of the divide path, measured

The same counter build, run on the full image: `DIV-blocks=25 sf1=22 sdiv=10 sf0=3
take=268 borrow=17`. So 22 of the 25 rows execute the new pair divide (three
exercise the retained 32-bit path, ten of them signed), and the multiply/CSel/FP
fixtures report `DIV-blocks=0` -- no other probe enters this code, and no other
probe can be passing because of it.

## Gates

* `./sx target test-sxisaexec` -- `[OK]`, 25 divide rows plus the six older images,
  all passing; the walk/tiling check runs inside it.
* `./sx target test-native32`, `test-native-arm64`, `test-native-riscv64` -- `[OK]`.
* `./sx migration` -- 241/241.
* The generated 25-row image is 4736 bytes with a 1224-byte code region, unchanged
  in size from the 22-row table's image, and the fixtures on disk are the ones the
  gate itself writes, so there is no hand-placed binary in this increment.

## Still open (R20)

RV64 has `mulw`/`divuw`/`remuw` only -- no 64-bit `mul`/`mulh`/`div`/`rem` and no
RV64 twin of these images. `FADD`/`FSUB`/`FDIV` still rest on the whole-image
fixture. And `SMULH`/`UMULH` are *not* decoded: block 5 dispatch tests `mid5 == 27`
and consults bits 21 and 23, but never bit 22 or `Rm == 31`, so `SMULH x10, x7, x8`
runs as `SMADDL` and returns the low 64 bits instead of the high ones. That is the
same class of silent-wrong defect this increment removed for divides, and it should
be a refusal before it is a decoder.
