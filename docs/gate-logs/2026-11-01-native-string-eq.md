# Gate log — 2026-11-01 — `string_eq` in `tools/native32.sa` (i386/AArch64/RV64IM)

## Increment

`string_eq(A, B)` for the multi-ISA emitter. Each argument is a declared string
variable or a quoted literal; the expression yields `1` or `0` as a number, so it
drives `when`/`while` conditions, `show`, and composition with the numeric
operators.

Emission: push `(pointer, length)` for A, then for B, then `call` a comparison
routine emitted **once per image**. The routine pops the four stack values,
compares lengths (different ⇒ 0), then walks both byte spans (differing byte ⇒
0, exhausted ⇒ 1) and pushes the result. The routine sits behind a jump and
before the exit sequence, so the body cannot fall into it and the container
check's "image ends with the process exit" pin still holds.

Touched sources:

- `tools/native32.sa` — `string_eq` token hook (shape check, argument
  resolution, literal bytes appended to the data segment), `emit_streq_routine`
  for the three ISAs, `patch_call` for the forward call, `literal_body`, the
  tokenizer's `,` token, and the "this backend has no functions" filter now
  exempting `string_eq`.
- `tools/sxisaexec.sa` — 64-bit AArch64 ADD/SUB (immediate and shifted register)
  now set `N`/`Z`/`C`/`V`; see R16.
- `tools/sxisa_gates_lib.sa` — `streq` added to the fixture list, i386 image size
  pinned at 4270, refusal matrix 18 → 22.
- `tools/sxisaexec_test.sa` — `verify_six_way` for `streq`.

## Fixture

`selfhost/native32_tests/streq.sa`. Reference output (identical on seed-min,
gen2, x86-64 native AOT, i386, AArch64, RV64 and the portable IR VM):

```
1
1
1
0
0
0
1
0
0
1
1
1
equal
3
2
```

Coverage: literal on the right, literal on the left, variable pair, unequal
bytes at the same length, unequal lengths, empty vs empty, empty vs non-empty,
a copied value, composition with `==`, a `when` branch, equality re-evaluated in
a loop body, and equality as the loop condition itself.

Refusals (all with a `native32: ` diagnostic):

```
refuse/streq_arity.sa    line 2: string_eq expects exactly two string variables or string literals
refuse/streq_numeric.sa  line 2: string_eq needs string variables, not numeric values
refuse/streq_unknown.sa  line 2: unknown name 'nope' in string_eq
refuse/streq_comma.sa    line 1: a ',' is only allowed between the two arguments of string_eq
```

## Images

All three images are 4270 bytes and their data segments are byte-identical (174
bytes from file offset 4096), because a literal argument only contributes its
bytes, never a per-arch address. Reviewed goldens:
`selfhost/native32_tests/golden/streq.arm64.elf`,
`selfhost/native32_tests/golden/streq.riscv64.elf`.

## Gates

```
./sx target test-native32        -> 0
./sx target test-native-arm64    -> 0   (gates run separately)
./sx target test-native-riscv64  -> 0
./sx target test-sxisaexec       -> 0   ([ok] 6-way execution parity verified on streq)
```

## Negative controls (each run live, then restored)

1. i386 image size pinned to 4240 instead of 4270:

```
[FAIL] reviewed i386 image size: got 4270, want 4240
EXIT=1
```

2. One byte of `golden/streq.arm64.elf` flipped:

```
[FAIL] reviewed machine-code golden (…/streq.elf != selfhost/native32_tests/golden/streq.arm64.elf)
EXIT=1
```

3. `tools/sxisaexec.sa` reverted to `HEAD` (the pre-fix emulator):

```
[FAIL] sxisaexec_test: streq seed vs AArch64 sxisaexec: mismatch at byte 0
EXIT=1
```

With the fix restored the same gate prints `SXISAEXEC-PARITY-OK` and exits 0, so
the emulator change is load-bearing and pinned by this fixture.

## R16 — 64-bit AArch64 add/subtract flags

The emulator decoded 64-bit ADD/SUB (immediate: `mid5 == 17`, shifted register:
`mid5 == 11` with `sf == 1`) and wrote the register result, but the flag block
existed only in the 32-bit arm, so `N`/`Z`/`C`/`V` kept whatever the previous
instruction produced. A 64-bit `cmp` (`subs xzr, …`) followed by `b.cond`
therefore branched on stale flags. Symptom while writing `string_eq`: AArch64
printed `0,1,1,1,1,1,1,1,1,1,1,0` where the other five paths printed the
reference output above; `cmp w1, w3` (32-bit) was unaffected, which is what
identified the 64-bit path. `tools/sxisaexec.sa` now computes, for both forms,
`N` from bit 63, `Z` from the 64-bit zero result, `C` from carry-out (ADD) or
no-borrow (SUB), and `V` from the sign of `(a ^ r) & (b ^ r)`.

## Full local CI

`./sx ci` on this tree, run in the background (it takes far longer than a
five-minute foreground call):

```
$ ./sx ci > /tmp/ci_r02s2.log 2>&1; echo EXIT=$?
...
[OK] full contract: 76 positive executions + 136 checked C refusals witnessed
[OK] full contract negative controls: missing/duplicate IDs and executions, stale case, bad kind, corrupted pin rejected
[OK] published-language v1: complete clause and builtin inventory, source/case pins
=== TRUE-SELFHOST-FULL-V1-OK ===
[OK] complete original CI acceptance chain and published-language v1 full acceptance
EXIT=0

$ grep -c '^\[OK\]' /tmp/ci_r02s2.log   # 570
$ grep -c '\[FAIL\]'  /tmp/ci_r02s2.log # 0
```

The pin manifests were refreshed before the run because this increment touches
pinned sources: `tools/native32.sa`, `tools/sxisaexec.sa`,
`tools/sxisa_gates_lib.sa`, `tools/sxisaexec_test.sa`, `README.md` and
`docs/REMAINING_WORK.md` in `docs/full-language-v1.sha256`, and that manifest's
own digest in `bootstrap/sx.sha256`. `sha256sum -c` is clean for all three
manifests and `./tools/sxddc self-test` exits 0.

## Remote acceptance

Tracked in the pull request; not predicted here.
