# R02 increment: `show` of a whole struct value (native32)

`docs/REMAINING_WORK.md` lists "whole values" among the open struct operations.
A *print* is the one whole-value operation that needs no calling convention, so
it is the bounded step. This closes it for the three native32 ISAs and **not**
for the C lanes, which still refuse the form — stated here rather than implied by
a gate name.

Branch `arena/9a8509bd-sayanox`, on top of `main` at `6ffc399`.

## What was refused before

```
$ ./tools/native32 struct_whole_value.sa out.elf i386
native32: line 3: unknown name 'p'

$ ./selfhost/seed/sxc_seed_min same.sa
min: show value cannot be a struct
```

The native32 diagnostic was `unknown name` because only a struct's *fields* are
bound in `names` (`p.x`, `p.y`), never the struct itself. That is why the
refusal read as a name error rather than as an unsupported form.

## What is implemented

`show <name>` where `<name>` was bound by a struct literal now prints one line per
field:

```
$ cat struct_show.sa          $ ./struct_show
struct Point { x, y }         p.x=3
struct Triple { a, b, c }     p.y=4
hold p = Point { 3, 4 }       q.x=10
hold q = Point { 10, -2 }     q.y=-2
hold t = Triple { 1, 2, 3 }   t.a=1
show p                        t.b=2
show q                        t.c=3
show t
```

**No new output shape was invented.** Each field emits two constructs the emitter
already has: a string literal for `name.field=` (the same code path `show "..."`
uses) and the existing decimal print routine. So the output format *is* the
language's own `show` concatenation, and a field's value is read from the same
slot `name.field` already resolves to. The new code is 69 lines of dispatch in
`tools/native32.sa`; no new emitter primitive.

## Scope boundaries, each with a named diagnostic

| Form | Result |
| --- | --- |
| all-numeric struct | printed, field by field |
| a struct with a **string** field | `showing a struct with a string field is not supported: 'r.name'` |
| a field whose inferred kind is still **unknown** | `cannot show struct 'p' because field 'f' has no established type` |
| a struct never bound | unchanged `unknown name` |

A string field is refused rather than flattened because a string operand is a
`(pointer, length)` pair and one decimal print consumes one scalar. Printing the
pointer would be wrong output, not partial output.

## Refusal-matrix delta

| Directory | Before | After |
| --- | --- | --- |
| `native32_tests/refuse` | 105 | **106** |

The 105 becomes 106 by two moves, both required by the rule that a fixture must
exercise the code as it now is:

- **−1**: `refuse/struct_whole_value.sa` was `show p` on a numeric struct — that
  is now the feature. Leaving it in `refuse/` would have failed, and keeping the
  feature out to protect a pin would have been the tail wagging the dog. It is
  replaced by the acceptance fixture `struct_show.sa` with a frozen `.want`.
- **+2**: `refuse/struct_show_string_field.sa`, `refuse/struct_show_unknown_kind.sa`.

All other pinned counts are unchanged: `struct_mutation_refuse` 6,
`struct_string_refuse` 9, `struct_string_initializer_refuse` 3, `len_refuse` 17,
`sxmod_tests/refuse` 16.

## Evidence

| Check | Result |
| --- | --- |
| `struct_show.want` (hand-checked, independent of the compiler) | 7 lines, matches i386 run |
| i386 determinism | two builds byte-identical |
| reviewed goldens | `golden/struct_show.arm64.elf`, `golden/struct_show.riscv64.elf`, 8284 bytes each |
| AArch64 executed | `tools/sxisaexec` reproduces all 7 lines |
| RV64IM executed | `tools/sxisaexec` reproduces all 7 lines |
| `test-native32`, `test-native-arm64`, `test-native-riscv64`, `test-sxisaexec` | exit 0 |

## Negative controls, and the row that caught each

| # | Break | Row that caught it |
| --- | --- | --- |
| B | string-field refusal removed from `tools/native32.sa` | `negative backend control unexpectedly passed` |
| C | per-field value print dropped (labels only) | `whole-struct show independent oracle` / `byte length 44 vs 28` |

Both mutants were applied to the **source**, not the binary: `sx target
test-native32` rebuilds `native32` from `tools/native32.sa`, so mutating only the
executable proves nothing and the first attempt at control B did exactly that and
silently passed. Restored byte-exact afterwards (`git diff --quiet` clean).

## Honest limits

- **Three ISAs, not six.** `seed-min`, `gen2` and `native_aot` still refuse
  `show <struct>`. `verify_six_way` was deliberately *not* called for this
  fixture; `verify_native_only_list` is. Making the C lanes print structs means
  changing `selfhost/compiler_min.sa`'s `rk == 3` path, which needs the kind of
  every field at the `show` site, plus `sxc_seed_min.sa`, `native_aot.sa` and
  `selfhost/modules/compiler_text.sa`. That is a separate increment and is not
  claimed here.
- **Numeric fields only.** String fields are refused by name; there is no
  partial output for them.
- **Nested structs** are not flattened and not printed; a nested field has no
  established kind, so the unknown-kind refusal fires.
- **No format control.** The `name=value` layout is fixed. There is no width,
  padding or separator option, and adding one is not in this increment.
- **`.want` is hand-checked, not independently generated.** It is an oracle by
  review, not by construction.
- R02 (full native parity) and R04 (precise GC) remain open.
