# Gate log — 2026-11-02 — R02 step 6: `chr` of an integer expression

## What was refused before

```
$ ./tools/native32 chr_expr.sa out.elf i386      # hold n = 5 ; show chr(n + 1)
native32: line 2: chr accepts an integer literal or a numeric variable in native32
```

`chr_arg` also rejected any argument containing `(`, `)` or `,`, so
`chr(len(s) + 62)` could not even be parsed.

## The change

- `chr_arg` scans its argument with parenthesis nesting: `chr((n + 60) + 1)` and
  `chr(len(s) + 62)` parse, a top-level comma is still the arity refusal, an
  unbalanced parenthesis is refused.
- The parser keeps the direct lowering when the argument is an integer literal
  or a bare numeric name, and otherwise sets the argument text as the statement's
  expression (`chr_acc = 1`), so the ordinary expression block compiles it first.
- The `chr` emission block then parks the accumulator value in a shared 4-byte
  scratch word (`chr_acc_slot`, allocated on first use) and reads it back through
  the numeric-slot path (`chr_spec(1, 0, scratch)`), leaving the per-occurrence
  byte cell with its `[byte][newline][0][0]` layout.

Machine code and data for every existing fixture are unchanged: the pinned i386
sizes (`expr` 8240, `flow` 8272, `text` 8285, `strcopy` 8309, `streq` 8370,
`chr` 8358, `chr_nested` 8534, `concat_expr` 8590) are the same, and their
AArch64/RV64IM goldens did not need regeneration.

## Fixture

`selfhost/native32_tests/chr_expr.sa` — nine output lines:

```
A      show chr(n + 61)              (n = 4)
A      show chr(n * 16 + 1)
A      show chr((n + 60) + 1)        parenthesised subexpression
A      show chr(len(s) + 62)         with s = "abc"
A      show chr(65 + 0)              literal in an expression
B      hold e = chr(n + 62) ; show e
B      hold m = 1 ; m = m + 1 ; show chr(m + 64)
       hold z = chr(n - 4) ; show z  -- chr(0) is empty text: one line break
done
```

Six execution paths agree (seed-min, gen2, x86-64 native AOT, Portable IR VM,
i386 ELF32, AArch64/RV64IM under `sxisaexec`); i386 image 8313 bytes, the two
goldens are 8313 bytes each and all three data segments are identical.

## Refusals (matrix 36 -> 39)

`refuse/chr_expression.sa` (`hold s = chr(n + 1)`) was **deleted** — that
program is now accepted. Four refusals were added:

```
refuse/chr_expr_string.sa   -> line 2: string variable 's' used as a number (index it with [i])
refuse/chr_expr_unknown.sa  -> line 1: unknown name 'k'
refuse/chr_expr_arity.sa    -> line 2: chr expects exactly one numeric argument
refuse/chr_expr_streq.sa    -> line 2: string_eq expects exactly two string values (a string variable, a string literal or chr(...))
```

`refuse/chr_nested_expression.sa` still refuses `concat(chr(n + 1), "x")`:
`concat`, `string_eq` and `len` parse their arguments by token count, so an
expression-shaped `chr` argument needs its own lowering there. That is the
documented next step, not a silent widening.

## Gates

```
./sx target test-native32        -> 0
./sx target test-native-arm64    -> 0
./sx target test-native-riscv64  -> 0
./sx target test-sxisaexec       -> 0
./sx target test-doc-claims      -> 0
```
