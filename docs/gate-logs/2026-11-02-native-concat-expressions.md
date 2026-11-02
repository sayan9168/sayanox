# Gate log — 2026-11-02 — R02 step 5: general string-valued expressions

`show concat(A, B)` and `concat` nested as a `concat` operand, in the
multi-ISA backend.

## What was refused before

```
$ ./tools/native32 show_concat.sa out.elf i386      # show concat("a", b)
native32: line 1: the native32 subset does not accept a call to 'concat' (this backend has no functions)

$ ./tools/native32 nested_concat.sa out.elf i386    # hold x = concat(concat(a, b), c)
native32: line 2: concat arguments must be string variables, string literals or chr(...) values
```

`concat` was only accepted as the whole value of a `hold` or an assignment, with
operands limited to variables, literals and `chr(...)` values; the emitter had
one inline block that resolved and copied in a single pass, so a nested call had
no destination to be emitted into.

## The refactor

The inline block became three functions over the compiler's file-scope state
(`code`, `data`, `fixsite`, `fixoff`, `names`, `strnames`, `heap_on`,
`heap_cursor_slot`, `concat_show_slot`, `arch`, `lineno`, hoisted out of
`run()`):

| function | job |
|---|---|
| `materialize_concat_operand(text)` | resolve one operand to a `(pointer, length)` pair slot: a variable's own pair; a literal's pair, whose pointer and length are written by the program at run time (data image stays arch-neutral, R14); a `chr` cell; or a nested call, emitted first into a hidden pair slot |
| `emit_concat_copy(leftslot, rightslot, dest)` | the one copy routine into the bounded bump heap — the same machine code as before |
| `emit_concat_pair(left, right, dest)` | resolve both operands, then copy |
| `emit_show_string_slot(s)` | the string-print sequence, now shared by `show NAME`, `show chr(...)` and `show concat(...)` |

`split_concat` became parenthesis-aware (a comma only separates operands at
depth 0), `arg_is_static_string` accepts a nested `concat(` operand, and nesting
is capped at seven levels.

## Fixture

`selfhost/native32_tests/concat_expr.sa` — 13 output lines:

```
leftright          show concat(a, b)
AB                 show concat("A", "B")
xleft             show concat("x", a)
left-right        hold c = concat(concat(a, "-"), b)
pre-left!         hold d = concat("pre-", concat(a, "!"))
1234              hold e = concat(concat("1", "2"), concat("3", "4"))
pqr               show concat(concat("p", "q"), "r")
Aright            show concat(chr(65), b)
leftB             show concat(a, chr(66))
abcdef            four-level nesting
6                 len(deep)
3                 the numeric name is untouched
1                 string_eq(concat result, "leftright")
```

Six execution paths: seed-min, gen2, x86-64 native AOT, Portable IR VM, i386
ELF32 (run directly on this kernel) and AArch64/RV64IM under `sxisaexec`. All
six produce the block above; the reviewed goldens
`golden/concat_expr.{arm64,riscv64}.elf` are 8590 bytes each and their data
segments (398 bytes) are byte-identical to the i386 image's.

## Refusals (matrix 31 -> 36)

```
refuse/concat_nested_var_num.sa   -> line 2: concat variable arguments must be strings
refuse/concat_nested_operand.sa   -> line 1: concat inputs must be declared string variables, string literals, chr(...) values or nested concat calls
refuse/concat_nested_arity.sa     -> line 1: concat requires two string arguments
refuse/concat_nested_deep.sa      -> line 1: concat nesting is limited to seven levels
refuse/concat_streq_arg.sa        -> line 2: the native32 subset does not accept `concat(...)` inside another expression (only as the whole value of a `hold`, an assignment or a `show`)
```

The last message replaced "a call to 'concat' (this backend has no functions)",
which had stopped being true.

## Pins

`chr` operand slots are now allocated during emission instead of during
parsing, so the reviewed goldens of the two `concat` fixtures were regenerated.
Image sizes are unchanged: `chr_nested` 8534, `concat_expr` 8590, data
identical on all three targets.

## Gates

```
./sx target test-native32        -> 0
./sx target test-native-arm64    -> 0
./sx target test-native-riscv64  -> 0
./sx target test-sxisaexec       -> 0
./sx target test-doc-claims      -> 0
./sx target test-sxbuild         -> 0
```
