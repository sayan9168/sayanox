# Gate log — 2026-11-07 — R02 step 11: bounded recursion with per-depth frames

## Where this increment starts

The frame design landed as work in progress in #71: `make` bodies got their own
value-stack frames, arguments moved from fixed parameter slots to the stack, and
a depth counter was added. Finishing it meant four separate things, and this log
covers all four:

1. an RV64IM encoder defect that made **any** body-to-body call crash,
2. the new behaviour had no fixture and no six-way execution,
3. the gates still expected the previous refusal matrix and image sizes,
4. the current guides still said recursion was refused.

The starting state, on the merged tree:

```
$ ./tools/native32 selfhost/native32_tests/fn.sa /tmp/fn.rv riscv64
$ ./tools/sxisaexec --arch riscv64 --out /tmp/fn.rv.out /tmp/fn.rv
sxisaexec: unmapped memory access at vaddr 0        -> exit 1
$ ./tools/sxisaexec --arch arm64 --out /tmp/fn.arm.out /tmp/fn.arm64
                                                    -> exit 0, 19 lines
$ ./tools/native32 selfhost/native32_tests/refuse/fn_recursion.sa /tmp/x.elf i386
                                                    -> exit 0 (no longer a refusal)
```

So the merged tree was red in the two ways that matter: the refusal matrix
counted a program that is legal now, and `fn` ran on two targets out of three.

## The defect: the RV64 link-register slot

The prologue pushed the link register with `sd ra,8(sp)` and the epilogue popped
the caller's frame base and jumped straight back through `ret` — the saved `ra`
was never reloaded, and the slot it had been saved in was not the one the
epilogue's frame shape expects. A single-level call hid this completely: `x1`
was still live when the body returned. The first body-to-body call destroyed it,
because `jal` overwrites `x1`:

```
# before, RV64IM fn.sa prologue / epilogue (capstone on the emitted image)
000558  23301100  sd   ra, 8(sp)          <- saved at +8
...
00127c  83350100  ld   a1, 0(sp)          <- caller frame base
001280  13010101  addi sp, sp, 0x10
00128c  23a0b200  sw   a1, 0(t0)          <- caller frame base restored
001290  67800000  ret                     <- no `ld ra`: returns through x1
```

AArch64 does not have the defect because it saves with a pre-decrement store at
displacement 0 and reloads `x30` from the frame before returning:

```
000364  fe0741f8  ldr x30, [sp], #0x10
000368  c0035fd6  ret
```

The fix mirrors that shape: store at 0, reload at 0.

```
# after
000558  23301100  sd   ra, 0(sp)
00064c  83300100  ld   ra, 0(sp)          (+ addi sp,sp,16, then ret)
```

The reload is an `ld`, not an `lw`: the first version of the fix used a 32-bit
load, which happened to work only because every image address is below 2^31 and
sign-extends back to itself. Disassembling the emitted image is what caught it.

## Fixtures

`selfhost/native32_tests/recursion.sa` — 12 output lines, i386 **8259** bytes,
reviewed AArch64/RV64IM goldens, identical bytes on all six execution paths:

| source | expected | printed |
| --- | --- | --- |
| `show fact(5)` | 120 | 120 |
| `show fact(8)` | 40320 | 40320 |
| `show fib(10)` | 55 | 55 |
| `show even(10)` / `show odd(9)` | 1 / 1 | 1 / 1 |
| `show sumto(5)` | 15 | 15 |
| `show doublings(2)` (parameter reassignment) | 5 | 5 |
| `hold r = sumto(4)` / `show r + 1` | 11 | 11 |
| `when even(8) == 1 { show "even" }` | even | even |
| `show fib(6) * fact(3)` | 48 | 48 |
| `when fact(4) + sumto(2) == 27 { show "operands" }` | operands | operands |
| `show "done"` | done | done |

`sumto` is the per-depth test: with one shared frame it collapses to
`n + (n-1) + ... ` of a single slot and prints `5 * 1` instead of `15`; the
fixture therefore fails on a shared-slot implementation, not only on a crash.
Every shown value stays below 10^6 because the double-based C backends print a
`num` with six significant digits (`3628800` appears as `3.6288e+06`), and the
fixture has to agree with them to be a six-way fixture at all.

`selfhost/native32_tests/fn_depth_cap.sa` — `give down(n + 1)`; the 65th live
frame reaches the shared overflow stub:

```
$ ./tools/native32 .../fn_depth_cap.sa /tmp/cap.i386 i386 && /tmp/cap.i386
                                                       -> exit 1, 0 bytes
$ ./tools/sxisaexec --arch arm64   --out /tmp/cap.arm.out /tmp/cap.arm64
                                                       -> exit 1, 0 bytes
$ ./tools/sxisaexec --arch riscv64 --out /tmp/cap.rv.out  /tmp/cap.rv
                                                       -> exit 1, 0 bytes
```

`fn.sa` keeps its content but is re-pinned at i386 **8265** bytes (the frame
code changed the image, not the program), and both `fn` and `recursion` were
added to the six-way list in `tools/sxisaexec_test.sa`, which they were not in
before.

## Refusals (52 -> 52)

Deleted because the programs are accepted now:

- `refuse/fn_recursion.sa` — `give fact(n - 1)`
- `refuse/fn_mutual_recursion.sa` — `ping`/`pong`
- `refuse/fn_recursion_in_operand.sa` — `give f(n) + 1`

Added, so the matrix stays at 52 and every entry is still a real refusal:

| fixture | diagnostic |
| --- | --- |
| `refuse/fn_bigframe.sa` | `line 61: a make body keeps at most 60 words of locals in a frame` |
| `refuse/fn_many.sa` | `native32 v1 accepts at most 8 make declarations` |
| `refuse/fn_many_params.sa` | `native32 v1 accepts at most 6 parameters per make` |

The last two checks already existed but had no fixture; `fn_bigframe` exercises
the bound that the frame layout actually depends on.

## Gates

```
$ ./sx target test-native32        -> 0   (i386 pins 8265 / 8259, goldens, 52 refusals)
$ ./sx target test-native-arm64    -> 0   (golden byte equality, cross-ISA data)
$ ./sx target test-native-riscv64  -> 0   (golden byte equality, cross-ISA data)
$ ./sx target test-sxisaexec       -> 0
[ok] 6-way execution parity verified on fn (seed == gen2 == x86-64 == IR-VM == AArch64 == RV64IM)
[ok] 6-way execution parity verified on recursion (seed == gen2 == x86-64 == IR-VM == AArch64 == RV64IM)
[ok] recursion is capped at 64 frames and exits 1 with no output on AArch64 and RV64
SXISAEXEC-PARITY-OK
```

## Negative controls (each run for real, then reverted)

**Old tool, whole harness** — the previous `tools/native32` (built from the
merged tree) was put in place and `sxisaexec_test` was run against a clean
directory:

```
[FAIL] sxisaexec_test: fn: sxisaexec riscv64 failed          (sxisaexec: unmapped memory access at vaddr 0)
```

**Size pin**:

```
$ sed -i 's/expected = 8259/expected = 8258/' tools/sxisa_gates_lib.sa
$ ./sx target test-native32
[FAIL] reviewed i386 image size: got 8259, want 8258          -> EXIT 1
```

**Refusal matrix**:

```
$ sed -i 's/arch, 0, 52)/arch, 0, 51)/' tools/sxisa_gates_lib.sa
$ ./sx target test-native32
[FAIL] complete backend refusal matrix: got 52, want 51       -> EXIT 1
```

**A stale refusal left in place** (`refuse/fn_recursion.sa` restored, which is
exactly what the merged tree still had):

```
$ ./sx target test-native32
[FAIL] negative backend control unexpectedly passed            -> EXIT 1
```
