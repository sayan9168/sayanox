# Gate log — 2026-11-02 — nested `chr` in `tools/native32.sa`

## Increment

`chr(X)` is now a value inside the three calls that take strings, in every
argument position:

```
hold s = concat(chr(65), "x")            // left of concat
hold t = concat("x", chr(65))            // right of concat
hold u = concat(chr(a), chr(b))          // both sides
hold e = string_eq(chr(65), "A")         // either argument
hold f = string_eq(chr(a), chr(b))       // both arguments
hold m = len(chr(65))                    // len's argument
```

`X` is still one decimal integer literal or one declared numeric variable, in
the nested positions exactly as in the whole-value positions.

## How it is emitted (no new push form)

`concat` and `string_eq` push `(pointer, length)` pairs; the statement-level
`chr` already knew how to build such a pair. So the nested form *hoists* that
sequence instead of adding a third push form:

1. at classification time the backend reserves two hidden data slots per
   side — an 8-byte `(pointer, length)` pair for the argument, and nothing else;
2. at emission time `emit_chr_value` writes the committed cell — 4-byte cell
   `[byte][newline][0][0]`, one-byte store (a 32-bit store would wipe the
   newline), `udiv`/`sltu`/`test`+`setne` low-byte length, pointer
   `cell + 1 - length` — into that pair;
3. the existing `concat`/`string_eq` push paths then read the pair as if the
   argument had been a plain string variable, and `len` reads its length half.

Every address is an absolute immediate, because the data base is fixed per
target (`134520832` on i386, `4202496` on AArch64/RV64IM), so no fixup is
involved. Nothing is allocated, so a nested `chr` cannot consume the 60 KiB
concat heap. Shared helpers: `chr_kind_of` (one argument rule for both
positions), `emit_chr_value` (the per-ISA sequence), `emit_load_abs` (absolute
load, no fixup), `tok_name_is` (a name token that spells a given word).

The refactor is behaviour-preserving for the committed `chr` fixture and its
goldens were regenerated only because the AArch64/RV64 literal path now emits
`movz`/`movk` into `w0` directly instead of push/pop; the i386 image is still
8354 bytes and the six-way output is unchanged.

## A published limit the gate caught

The first version of the helper took eight parameters
(`emit_chr_value(xs, arch, kind, val, srcslot, cell, dst, base)`). That compiles
with `bootstrap/sxc_native.bin`, but the published language allows **at most six
parameters per `make`**, and `test-native-sxdefs` compiles `tools/native32.sa`
itself with `native_aot`, which enforces the limit:

```
native_aot: make emit_chr_value: at most 6 params
[FAIL] backend artifact: expand.sa (…/tools_native32/expand.sa != …/tools_native32/sx.expand)
sxbuild: target failed: test-native-sxdefs
```

The fix keeps the code inside the documented subset rather than loosening the
limit: the three per-site values are bundled into a `chr_spec(kind, value, src)`
list and the data base is derived from `arch` inside the emitter, so
`emit_chr_value` takes five parameters. Generated image sizes and goldens are
unchanged by that refactor.

## Fixture

`selfhost/native32_tests/chr_nested.sa`, 14 output lines, identical on i386,
AArch64 and RV64 (and on seed-min, gen2 and the x86-64 AOT backend):

```
Bcd xC DE F! q 1 1 0 1 3 75 Aab 9
```

| line | program | why |
|---|---|---|
| `Bcd` | `concat(chr(66), "cd")` | `chr` left of a literal |
| `xC` | `concat("x", chr(67))` | `chr` right of a literal |
| `DE` | `concat(chr(68), chr(69))` | two nested `chr` |
| `F!` | `concat(chr(n), "!")` | `chr` of a numeric variable |
| `q` | `concat(chr(0), "q")` | empty `chr` as a `concat` operand |
| `1` | `string_eq(chr(65), "A")` | `chr` on the left |
| `1` | `string_eq("B", chr(66))` | `chr` on the right |
| `0` | `string_eq(chr(67), chr(68))` | two nested `chr`, unequal |
| `1` | `len(chr(72))` | length half of a hoisted pair |
| `3` | `show len(w)` | `w = concat(chr(74), "KL")` |
| `75` | `show w[1]` | byte `'K'` of that result |
| `Aab` | `a = concat(chr(65), a)` | nested `chr` in an **assignment** form, reading the variable it writes |
| `9` | `when string_eq(chr(70), ff) { show 9 }` | nested `chr` in a branch condition |

All three images are 8534 bytes. Reviewed goldens:
`golden/chr_nested.arm64.elf`, `golden/chr_nested.riscv64.elf`.

### Data segment: layout pin instead of byte equality (R14)

`chr_nested` is the first accepted program whose data segment cannot be
byte-identical across ISAs: a `concat` **literal** argument stores its pointer
(data base + offset) in the data segment at layout time, and the data base
differs per target, so the same 342-byte segment carries different pointer bytes
on i386 and on AArch64/RV64IM. This is R14, recorded before this increment.

The gate therefore asserts the data-segment *size* (342 bytes) on each target
through the new `xc_data_layout`, keeps the five older fixtures on the full
byte-for-byte cross-ISA comparison, and covers the bytes themselves with the
reviewed per-arch goldens plus six-way execution parity. Nothing was skipped
silently: the assertion was narrowed, named, and pinned.

## Refusals

Matrix 26 -> 31 (each still prints a `native32: ` diagnostic):

```
refuse/chr_nested_arity.sa       line 1: concat accepts exactly two arguments
refuse/chr_nested_string.sa      line 1: chr accepts an integer literal or a numeric variable in native32
refuse/chr_nested_unknown.sa     line 1: unknown name 'nope' in chr
refuse/chr_nested_expression.sa  line 2: chr accepts an integer literal or a numeric variable in native32
refuse/streq_chr_numeric.sa      line 2: string_eq needs string variables, not numeric values
refuse/len_chr_string.sa         line 2: chr needs a numeric value, not a string
```

`refuse/concat_call.sa` (`concat(text, chr(121))`) was **deleted**: that program
is now legal in this backend, so it can no longer be a refusal fixture. The i386
"accepted by the C backend while native32 refuses it" list no longer names it,
and `chr_nested.sa` is its replacement. The `split_concat` message also stopped
saying "string arguments", since an argument may now be a `chr` value.

## Gates

```
./sx target test-native32        -> 0
./sx target test-native-arm64    -> 0
./sx target test-native-riscv64  -> 0
./sx target test-sxisaexec       -> 0
./sx target test-doc-claims      -> 0
./sx target test-ci-shape        -> 0
```

```
$ ./sx target test-sxisaexec | grep chr
[ok] 6-way execution parity verified on chr (seed == gen2 == x86-64 == IR-VM == AArch64 == RV64IM)
[ok] 6-way execution parity verified on chr_nested (seed == gen2 == x86-64 == IR-VM == AArch64 == RV64IM)
```

The six-way comparison is the oracle: seed-min, gen2, x86-64 native AOT, i386,
AArch64 and RV64 all print the same bytes, so the hoisted pair is checked
against the other backends rather than against this emitter's own expectation.

## Negative controls (each run live on a scratch copy, then restored)

1. **Nested `chr` not tokenised** (drop `chr` from the tokenizer's call
   allowance). The fixture is refused at its first nested `chr` inside a call:

   ```
   native32: line 13: the native32 subset does not accept a call to 'chr' (this backend has no functions)
   exit=1
   ```

2. **Token-kind check removed from the `string_eq` `chr` argument.** The trap
   this check exists for: a string literal token carries a decoded *length*, so
   `chr("A")` was read as `chr(1)`. With the check removed the refusal fixture
   stops being a refusal and silently compiles:

   ```
   $ tools/native32 refuse/chr_nested_string.sa b.elf i386 ; echo exit=$?
   exit=0
   $ ./b.elf
   0
   ```

   With the check in place it prints
   `line 1: chr accepts an integer literal or a numeric variable in native32`
   and exits 1.

3. **Pointer correction removed** (`cell` instead of `cell + 1 - length` in all
   three ISA branches). The reviewed output no longer appears:

   ```
   0000000  \0   c   d  \n   x  \0  \n  \0  \0  \n  \0   !  \n   q  \n   0
   0000020  \n   1  \n   1  \n   1  \n   3  \n   7   5  \n  \0   a   b  \n
   ```

   versus the reviewed `B c d \n x C \n D E \n F ! \n q \n 1 \n 1 \n 0 \n 1 \n 3 \n 7 5 \n A a b \n 9 \n`
   (the `when` line disappears entirely, because `chr(70)` no longer reads `F`).

4. **`len` shape check off by one** (`k + 6 < tn` -> `k + 7 < tn`), so the
   `len(chr(...))` form is not recognised:

   ```
   native32: line 19: len() expects exactly one string variable, string literal or chr(...), not a general expression
   exit=1
   ```

5. **Size pin.** `chr_nested` pinned at 8538 instead of 8534:

   ```
   [FAIL] reviewed i386 image size: got 8534, want 8538
   sxbuild: target failed: test-native32
   ```

6. **Data-segment pin.** `xc_data_layout(..., 342)` raised to `346`:

   ```
   [FAIL] reviewed data segment size: …/chr_nested.elf: got 342, want 346
   ```

7. **Golden byte.** One byte of `golden/chr_nested.arm64.elf` flipped at offset
   200:

   ```
   [FAIL] reviewed machine-code golden (…/chr_nested.elf != selfhost/native32_tests/golden/chr_nested.arm64.elf)
   ```

## Full local CI

```
$ ./sx ci > /tmp/ci_chr_nested.log 2>&1; echo EXIT=$?
```
$ ./sx ci > /tmp/r02s4/ci.log 2>&1; echo EXIT=$?
...
[OK] full builtin signatures: 184 valid C builds; 944 checked arity/kind C refusals
[OK] full runtime boundaries: 40 checked range failures + 8 failed/oversize HTTP executions; imports: 4 depth-boundary executions + 16 checked refusals
[OK] full contract: 76 positive executions + 136 checked C refusals witnessed
[OK] full contract negative controls: missing/duplicate IDs and executions, stale case, bad kind, corrupted pin rejected
[OK] published-language v1: complete clause and builtin inventory, source/case pins
=== TRUE-SELFHOST-FULL-V1-OK ===
[OK] complete original CI acceptance chain and published-language v1 full acceptance
EXIT=0
```

569 `[OK]` lines, 0 `[FAIL]`, 283 gates, `EXIT=0`.

Pins after the last edit (`sha256sum -c` clean for all three manifests, and
`./tools/sxddc self-test` exit 0):

```
docs/full-language-v1.sha256   5 entries repinned: tools/native32.sa,
                               tools/sxisa_gates_lib.sa, tools/sxisaexec_test.sa,
                               README.md, docs/REMAINING_WORK.md
bootstrap/sx.sha256            manifest digest 4ea2d046d010129e88365dc1adb8605f0596ea3118e6616b856d46dc584521ee
```
