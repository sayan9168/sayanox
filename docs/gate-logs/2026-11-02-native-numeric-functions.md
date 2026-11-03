# Gate log — 2026-11-02 — R02 step 8: bounded numeric user functions

## What was refused before

```
$ ./tools/native32 refuse/function.sa out.elf i386    # make twice(v: num) { give v * 2 }
native32: line 4: the native32 subset does not accept a call to 'twice' (this backend has no functions)
```

## The change

1. **The statement walk became a function.** Everything from "the statement walk"
   to the "no statements" check moved out of `run()` into
   `emit_statements()`, with the program text (`src`), the block stack
   (`bkind`/`bsite`/`bstart`/`bdepth`), `ops` and `stmts` promoted to file scope.
   All nine existing fixtures rebuilt byte-identically afterwards (see the table).
2. **`lift_functions()`** scans the program text, and for every
   `make NAME(a: num, …) -> num {` header: validates the name, the parameter
   types, the `-> num` return type, duplicates and the caps (8 functions,
   6 parameters); allocates one 4-byte data slot per parameter; records the
   header line; and blanks the header and body lines in the text handed to the
   main walk, so diagnostics keep their original line numbers.
3. **Emission.** After the main program (and the `string_eq` routine), a jump
   skips over the function bodies; each body is walked by `emit_statements()`
   with its parameter table installed as the visible name table, `give` compiles
   its expression and emits `ret`, and after the last body the call sites are
   patched with `patch_call`.
4. **New per-ISA instructions** (only three, and each is the canonical one):
   `ret` (i386 `C3`, AArch64 `RET`, RV64IM `JALR x0, 0(x1)`), push-accumulator
   (`50` / `str x0,[sp,#-16]!` / the existing RV64 push) and a deferred `call`
   (`E8 rel32` / `BL imm26` / `JAL x1`).
5. **Calls** are detected in `emit_expression`: when the whole text is
   `NAME(...)` for a declared function, the arguments are rendered with
   `tok_range_text`, each is compiled and pushed, then popped into the callee's
   parameter slots in reverse order and the call is emitted. That makes calls
   work in `hold`, assignment, `show`, `when`/`while` conditions and as another
   call's argument. The tokenizer now accepts `NAME(` for a declared function
   instead of claiming the backend has no functions.

## Fixture

`selfhost/native32_tests/fn.sa` covers a two-argument function, a one-argument
function, an early `give` inside a `when` branch plus the trailing `give`, four
parameters, a `while` loop with a local accumulator and parameter assignment, a
zero-argument function, a call as `hold` initialiser, as `show` operand, as a
`when` condition and as another call's argument.

```
$ ./tools/native32 fn.sa fn.i386 i386 && ./fn.i386
5
30
6
10
3
7
10
7
8
yes
13
done
```

The same output on all three ISAs (`md5 63ceeec45623c9563d616d5d384d2f35` for
i386, AArch64 under `sxisaexec` and RV64IM under `sxisaexec`), the same image
size (8285) on all three, and the fixture is also run by the seed, gen2 and
native AOT backends inside the gate (`xq_parity_unknown`), which is what makes
"the same program prints the same thing everywhere" a checked claim.

## Refusals (matrix 40 -> 51)

`refuse/function.sa` deleted (legal now); twelve added, one per bound:

| fixture | diagnostic |
| --- | --- |
| `fn_recursion` | `'fact' is called from inside a make body; native32 v1 only lets the main program call a function` |
| `fn_call_in_body` | same, for a second function |
| `fn_give_outside` | `` `give` is only accepted inside a make body `` |
| `fn_no_give` | `the body of 'f' never gives a value with give` |
| `fn_not_last` | `the body of 'f' must end with a `give` statement` |
| `fn_untyped_param` | `every parameter needs a type, as in `a: num`` |
| `fn_str_param` | `native32 parameters are `name: num` only` |
| `fn_arity` | `'f' takes 1 numeric arguments, not 2` |
| `fn_str_arg` | `a call argument to 'f' must be a number, not a string` |
| `fn_dup_name` | `'f' is declared twice` |
| `fn_unknown` | `a call to 'g': no make with that name is declared` |
| `fn_string_return` | `native32 only accepts `make NAME(a: num) -> num {`` |

## Golden invariance after the walk extraction

Every pre-existing fixture was rebuilt with the new compiler; all nine are
byte-identical to the reviewed goldens and keep their pinned i386 sizes:

| fixture | AArch64 | RV64IM | i386 |
| --- | --- | --- | --- |
| `expr` | identical | identical | 8240 |
| `flow` | identical | identical | 8272 |
| `text` | identical | identical | 8285 |
| `strcopy` | identical | identical | 8309 |
| `streq` | identical | identical | 8370 |
| `chr` | identical | identical | 8358 |
| `chr_nested` | identical | identical | 8534 |
| `concat_expr` | identical | identical | 8590 |
| `chr_expr` | identical | identical | 8515 |

## Gates

```
$ ./sx target test-native32        -> 0
$ ./sx target test-native-arm64    -> 0
$ ./sx target test-native-riscv64  -> 0
```

## Negative controls

```
$ sed -i 's/expected = 8285/expected = 8286/' tools/sxisa_gates_lib.sa
$ ./sx target test-native32
[FAIL] reviewed i386 image size: got 8285, want 8286      -> 1

$ sed -i 's/arch, 0, 51)/arch, 0, 52)/' tools/sxisa_gates_lib.sa
$ ./sx target test-native32
[FAIL] complete backend refusal matrix: got 51, want 52    -> 1
```

Both were restored (gate back to exit 0).

## One defect found while building this

The RISC-V `ret` was first encoded as `0x806F`, which is `JAL`, not `JALR`; the
generated RV64IM image faulted with `memory permission fault at vaddr 4228096`
while i386 and AArch64 were already correct. `jalr x0, 0(x1)` is `0x8067` and the
three-ISA output equality above is the check that keeps it honest.
