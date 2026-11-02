# Gate log — 2026-11-02 — R02 step 7: `chr(<expression>)` as an argument

## What was refused before

```
$ ./tools/native32 refuse/chr_nested_expression.sa out.elf i386
native32: line 2: chr accepts an integer literal or a numeric variable in native32

$ ./tools/native32 refuse/chr_expr_streq.sa out.elf i386
native32: line 2: chr accepts an integer literal or a numeric variable in native32
```

`concat`, `string_eq` and `len(chr(...))` scan their arguments as token counts,
so an expression-shaped `chr` argument had no place to be compiled: the integer
expression emitter lived inside the statement loop.

## The change

- The expression emitter is now one function, `emit_expression(extext: str) -> num`,
  declared before `run()`. The statement loop calls it; nothing else about the
  statement path changed (`eq_used`/`eq_calls` moved to file scope, `ops` is
  declared per call because every slot is written before it is read).
- `paren_close(toks, at, tn)` returns the index of the `)` matching the `(` at
  `at`, so the argument scan no longer assumes a fixed token distance.
- `tok_range_text(toks, from, upto)` renders a token range back into expression
  source; it accepts only numbers, names, parentheses and operators, and refuses
  anything else with a diagnostic instead of silently dropping a token.
- `emit_chr_expr_slot(toks, from, upto)` compiles that text with
  `emit_expression`, parks the value in the shared `chr_acc_slot` word and
  returns the slot, so the existing numeric-slot lowering
  (`chr_spec(1, 0, slot)` -> `emit_chr_value`) is reused unchanged.
- `string_eq` and `len(chr(...))` use all of the above; a one-token argument
  still takes the direct literal/name lowering.

## What compiles now

```
concat(chr(n + 1), "x")
concat("-", chr(n * 16 + 1))
string_eq(chr(n + 61), "A")
string_eq("A", chr(n + 61))
string_eq(chr(n + 61), chr(n + 62))
len(chr(n + 61))
len(chr(n - 4))
string_eq(chr(len(s) + 62), "A")      # nested call inside the argument
concat(chr((n + 1) * 16 + 1), "!")    # explicit grouping inside the argument
```

## A defect caught by the nested-call case

The first version of `tok_range_text` stripped one leading character from every
token. That is right for `v`/`n`/`o` tokens, but a parenthesis token *is* the
parenthesis, so `chr(len(s) + 62)` rendered as `lens+62` and the compiler said
`unknown name 'lens'`. Parentheses are copied whole now, and both cases are in
the fixture. All the gates below ran on the fixed compiler.

## What is still refused

```
$ ./tools/native32 refuse/chr_expr_string_arg.sa out.elf i386
native32: line 2: string variable 's' used as a number (index it with [i])

$ ./tools/native32 refuse/chr_expr_len_unknown.sa out.elf i386
native32: line 1: unknown name 'k'

$ ./tools/native32 refuse/chr_expr_div.sa out.elf i386
native32: line 2: the native32 subset does not accept division (/): a Sayanox number is a double and 7 / 2 is 3.5, which this integer backend cannot print
```

`concat` as an operand of another expression is still a statement-level form and
still refused.

## Golden invariance (the important check)

Every pre-existing fixture was rebuilt with the new compiler and compared:

| fixture | AArch64 golden | RV64IM golden | i386 size |
| --- | --- | --- | --- |
| `expr` | identical | identical | 8240 |
| `flow` | identical | identical | 8272 |
| `text` | identical | identical | 8285 |
| `strcopy` | identical | identical | 8309 |
| `streq` | identical | identical | 8370 |
| `chr` | identical | identical | 8358 |
| `chr_nested` | identical | identical | 8534 |
| `concat_expr` | identical | identical | 8590 |
| `chr_expr` | **regenerated** (fixture grew) | **regenerated** | 8313 -> 8515 |

`chr_expr.sa` output on the three ISAs was compared byte for byte
(`md5 b9b7ffe71154a9a10dda66da6c679188` on i386, AArch64 and RV64IM) and the
three images have identical size and a zeroed data prefix.

## Gates

```
$ ./sx target test-native32
[OK] native tool: native32
[OK] Sayanox ISA/module acceptance: test-native32
[OK] sxbuild target: test-native32
-> 0

$ ./sx target test-native-arm64
[OK] Sayanox ISA/module acceptance: test-native-arm64
-> 0

$ ./sx target test-native-riscv64
[OK] Sayanox ISA/module acceptance: test-native-riscv64
-> 0

$ ./sx target test-sxisaexec
[ok] AArch64 + RV64 syscalls: openat/read/write/close and file bytes match
[ok] IEEE-754 S/D arithmetic + integer conversion executed on AArch64 and RV64 F/D subset
SXISAEXEC-PARITY-OK
-> 0
```

Complete guarded CI on the same tree: `./sx ci` -> 0, 570 `[OK]`, 0 `[FAIL]`,
ending in `=== TRUE-SELFHOST-FULL-V1-OK ===`.

(The AArch64 and RV64IM gates run the same fixture on the native AOT backend, the
seed and gen2 C backends and under `sxisaexec`, and compare output, image and
reviewed goldens; the `i386` gate additionally executes the image when the
kernel allows it.)

## Negative controls

```
$ sed -i 's/expected = 8515/expected = 8516/' tools/sxisa_gates_lib.sa
$ ./sx target test-native32
[FAIL] reviewed i386 image size: got 8515, want 8516
-> 1

$ sed -i '144s/arch, 0, 40)/arch, 0, 41)/' tools/sxisa_gates_lib.sa
$ ./sx target test-native32
[FAIL] complete backend refusal matrix: got 40, want 41
-> 1
```

Both were restored and the gate went back to exit 0.
