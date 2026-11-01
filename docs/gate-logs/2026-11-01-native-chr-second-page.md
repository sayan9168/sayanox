# Gate log — 2026-11-01 — `chr(n)` in `tools/native32.sa`, and the second code page

## Increment

`chr(X)` for the multi-ISA emitter, in the three positions where a whole string
value is expected: `hold s = chr(X)`, `s = chr(X)` and `show chr(X)`. `X` is a
decimal integer literal or a declared numeric variable.

Semantics are the published runtimes', not this backend's invention:

- the low byte of the code is kept — `chr(300)` is byte 44, a variable holding
  `-1` gives byte 255 — which is what the C backend's `(char)(long)v` does;
- `chr(0)` is empty text with length 0 (`len(chr(0))` is 0), so `show` prints one
  newline and nothing else.

Emission, per source occurrence:

1. compute the code (literal push, or a load from the variable's slot);
2. mask to the low byte (`and eax,255` / `and w0,w0,w1` with `w1=255` /
   `andi a0,a0,255`);
3. write it with a **one-byte** store into a private 4-byte cell in the data
   segment, laid out as `[byte][newline][0][0]` — the newline is the invariant
   every `show` in this backend relies on, and a 32-bit store would destroy it;
4. the length is `1` for a nonzero byte and `0` for a NUL
   (`test`+`setne`+`movzx` on i386, `udiv w0,w0,w0` on AArch64 — division by zero
   is defined as 0 there, so no flag dependency is needed — and `sltu a0,x0,a0`
   on RV64);
5. the stored pointer is `cell + 1 - length`, so an empty `chr` points at the
   newline. Without that correction `show chr(0)` writes a NUL byte instead of a
   line break.

Nothing is allocated, so `chr` cannot consume the 60 KiB concat heap. Cells are
zero-filled in the image (only the newline byte is nonzero), so the data segment
stays arch-neutral.

## Why this increment had to move the text segment

The previous increment left the image **exactly** on the one-page ceiling:
`streq` was 4270 bytes = `4096` of header+code plus a 174-byte data segment, i.e.
`4096 - 116` bytes of code and zero bytes of headroom. `chr` needs ~40 bytes per
site, so no lowering could be emitted at all. The text segment is now two pages:

| | before | after |
|---|---|---|
| i386 text | `0x08048000`, 1 page | `0x08048000`, 2 pages |
| i386 data | `0x08049000` | `0x0804A000` |
| arm64/rv text | `0x400000`, 1 page | `0x400000`, 2 pages |
| arm64/rv data | `0x401000` | `0x402000` |
| code budget | `4096 - 116` / `4096 - 176` | `8192 - 116` / `8192 - 176` |
| `streq` image | 4270 B | 8366 B |

The emulator's image window grew from `0x400000..0x420000` (32 pages) to
`0x400000..0x424000` (36 pages) because the 60 KiB concat heap now starts at
`0x402000` and ends at `0x421000`. Every reviewed golden was regenerated: the
only changed words are the materialised data addresses (`movz x9,#0x4010` ->
`#0x4020` in the AArch64 diff, 96 words), and the data bytes are unchanged.

## Fixture

`selfhost/native32_tests/chr.sa`, 20 output lines, byte-identical on i386,
AArch64 and RV64:

```
A | 1 | B | C | , | 0xFF | 0 | <empty> | <empty> | Z | 1 | A | 65 | 1 | F | G | * | * | * | 3
```

(`<empty>` is a line that carries only the newline: `show nul` for
`nul = chr(0)` and `show chr(0)`.)

Coverage: literal and variable codes, the out-of-range code (300 -> `,`), a
negative code through a variable (-> `0xFF`), `chr(0)` as empty text, assignment
into an existing string variable, `len`, `s[0]` byte indexing, copy, `string_eq`
of a `chr` value, two live results in separate cells, and `chr` inside a loop.

All three images are 8354 bytes with a 162-byte data segment that is
byte-identical across the three ISAs (text differs, as it must). Reviewed
goldens: `golden/chr.arm64.elf`, `golden/chr.riscv64.elf`.

Refusals (matrix 22 -> 26), each with a `native32: ` diagnostic:

```
refuse/chr_arity.sa       line 1: chr expects exactly one numeric argument
refuse/chr_string.sa      line 2: chr needs a numeric value, not a string
refuse/chr_unknown.sa     line 1: unknown name 'nope' in chr
refuse/chr_expression.sa  line 2: chr accepts an integer literal or a numeric variable in native32
```

## Gates

```
./sx target test-native32        -> 0
./sx target test-native-arm64    -> 0
./sx target test-native-riscv64  -> 0
./sx target test-sxisaexec       -> 0   ([ok] 6-way execution parity verified on chr)
```

The six-way comparison is the oracle: seed-min, gen2, x86-64 native AOT, i386,
AArch64 and RV64 must all print the same bytes, so the low-byte rule and the
empty-`chr` rule are checked against the other backends rather than against this
emitter's own expectation.

## Negative controls (each run live, then restored)

1. **Size pin.** `chr` pinned at 8360 instead of 8354:

   ```
   [FAIL] reviewed i386 image size: got 8354, want 8360
   sxbuild: target failed: test-native32
   ```

2. **Golden byte.** One byte of `golden/chr.arm64.elf` flipped:

   ```
   [FAIL] reviewed machine-code golden (…/chr.elf != selfhost/native32_tests/golden/chr.arm64.elf)
   ```

3. **Pointer correction removed** (store `cell` instead of `cell + 1 - length`):

   ```
   [FAIL] reviewed machine-code golden (…/chr.elf != selfhost/native32_tests/golden/chr.arm64.elf)
   ```

4. **One-byte store replaced by a 32-bit store** (the byte value written over
   the newline). The fixture then prints a NUL after every character, so the
   six-way parity comparison fails:

   32-bit store (wrong):   `A \0 1 \n B \0 C \0 , \0 377 \0 0 \n \0 \0 Z \0 1 \n A \0 6 5 \n 1 \n F \0 G \0 * \0 * \0 * \0 3 \n`
   reviewed output:        `A \n 1 \n B \n C \n , \n 377 \n 0 \n \n \n Z \n 1 \n A \n 6 5 \n 1 \n F \n G \n * \n * \n * \n 3 \n`

## Full local CI

```
$ ./sx ci > /tmp/ci_chr.log 2>&1; echo EXIT=$?
...
[OK] full contract: 76 positive executions + 136 checked C refusals witnessed
[OK] full contract negative controls: missing/duplicate IDs and executions, stale case, bad kind, corrupted pin rejected
[OK] published-language v1: complete clause and builtin inventory, source/case pins
=== TRUE-SELFHOST-FULL-V1-OK ===
[OK] complete original CI acceptance chain and published-language v1 full acceptance
EXIT=0

$ grep -c '^\[OK\]' /tmp/ci_chr.log   # 570
$ grep -c '\[FAIL\]'  /tmp/ci_chr.log # 0
```

Pin manifests were refreshed before the run (`tools/native32.sa`,
`tools/sxisaexec.sa`, `tools/sxisa_gates_lib.sa`, `tools/sxisaexec_test.sa`,
`README.md`, `docs/REMAINING_WORK.md` in `docs/full-language-v1.sha256`, and that
manifest's own digest in `bootstrap/sx.sha256`). `sha256sum -c` is clean for all
three manifests and `./tools/sxddc self-test` exits 0.

## Remote acceptance

Tracked in the pull request; not predicted here.
