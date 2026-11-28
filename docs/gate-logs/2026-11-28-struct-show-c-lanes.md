# R02 increment 2 — `show <struct>` on the C lanes, six-way parity

Date: 2026-11-28
Branch: `arena/9a8509bd-sayanox`
Base: `7794363` (merge of PR #116)
Predecessor: `docs/gate-logs/2026-11-25-struct-whole-show.md` (native32 lanes only)

## What changed

PR #116 made `show <struct>` print on the three native32 ISAs but left the C
lanes refusing with `show value cannot be a struct`. This increment finishes the
feature on every lane that executes a program.

Five emitters had to agree, because they are five separate code paths:

| Lane | Site | Change |
| --- | --- | --- |
| seed-min (C) | `selfhost/compiler_min.sa` (`rk == 3`, `show` arm) | one `printf` per numeric field |
| gen2 / full seed (C) | same file | same code path |
| native_aot (x86-64 ELF) | `tools/sxemit_lib.sa` (`emit_prog`, struct `show`) | label via `wcstr`, value via `shownum` |
| sxc_native | `tools/sxemit_lib.sa` | same code path |
| Portable IR VM | `tools/sxirexec.sa` | implemented builtin 6 `wcstr` |

Two facts had to be established before the C lanes could work, and both were
wrong in the first attempt:

1. **Field kinds live in env tag 7 under the struct TYPE name, not the variable
   name.** The parser records `|Type.field=` + kind while it builds the struct
   value, and `sxelookup_span` strips the leading `|` before matching, so the
   lookup key is `Type.field` with no prefix. Keying on the variable name
   returned empty for every field.
2. **The kind digits are `0` number, `1` string, `2:<Type>` nested, `3` list.**
   `1` is a *string literal* in the same parser, not a number, so the first
   version refused every numeric field and accepted every string field.

The `show` operand identifier is `nm2`, not `nm`; `nm` in that scope is a
stale assignment target left over from the last `hold`, which is why the first
working version printed `t.x` for `p.x`.

## New gate

`struct_show` moved from `verify_native_only_list` to **`verify_six_way`** in
`tools/sxisaexec_test.sa`, with the frozen `struct_show.want` as the oracle on
every lane. The row now prints:

```
[ok] 6-way execution parity verified on struct_show (seed == gen2 == x86-64 == IR-VM == AArch64 == RV64IM)
```

## Refusal matrix delta

- `selfhost/native32_tests/refuse` stays at **106**. Both `struct_show` refusals
  (`struct_show_string_field`, `struct_show_unknown_kind`) still refuse.
- **New in this increment:** the C-lane refusal text was *not* pinned by any
  gate. A mutant that turned `when svkind == 48` into `when svkind >= 0` (which
  prints a string field as a number) passed `test-sxisaexec` before this change
  and is caught after it. `verify_c_lane_refusal` now pins both fixtures on
  seed-min and gen2.
- The original native-test matrix moved `native_showstruct` from the refusal
  list to the output-oracle list: **12 → 11 compile refusals, 21 → 22 output
  oracles**. That is a retired refusal, not a regression.

## Expectation counts per fixture

| Fixture | Lanes | Lines |
| --- | --- | --- |
| `struct_show` | 6 | 7 (`p.x=3`, `p.y=4`, `q.x=10`, `q.y=-2`, `t.a=1`, `t.b=2`, `t.c=3`) |
| `struct_show_string_field` | 2 C lanes | refusal, "is a string field" |
| `struct_show_unknown_kind` | 2 C lanes | refusal, "missing" |

## Negative controls

| ID | Mutation | Result |
| --- | --- | --- |
| A | `struct_show.want` last line `t.c=3` → `t.c=99` | **caught** — `whole-struct show independent oracle: byte length 45 vs 44` |
| B | `when svkind == 48` → `when svkind >= 0` (string field printed as a number) | **caught, but only after this increment** — `struct_show_string_field: seed-min must refuse: got 0, want 1`. Before adding `verify_c_lane_refusal`, this mutation passed the whole `test-sxisaexec` suite: the native32 `refuse/` matrix is a different lane from the C lanes. |
| C | Lookup key mutated to `Type.BOGUS.field` | **not caught** — a failed kind lookup defaults to numeric, and these fixtures are all numeric, so output was byte-identical. Noted as a real limit: the kind lookup is only *observable* through a non-numeric field, which control B covers. |

## Gate results (exit codes)

| Gate | Exit |
| --- | --- |
| `./sx doctor` | 0 |
| `./sx verify-entry` | 0 |
| `sha256sum -c bootstrap/sx.sha256` | 0 (67 entries) |
| `sha256sum -c bootstrap/native.sha256` | 0 (11 entries) |
| `sha256sum -c docs/full-language-v1.sha256` | 0 (299 entries) |
| `./sx target true-selfhost` | 0 |
| `./sx target gen3` (gen3 == gen4) | 0 |
| `./sx target test-native32` | 0 |
| `./sx target test-native-arm64` | 0 |
| `./sx target test-native-riscv64` | 0 |
| `./sx target test-sxisaexec` | 0 |
| `./sx target test-nest` | 0 |
| `./sx target native-test` | 0 |
| `./sx target test-driver` | 0 |
| `./sx target all-sayanox` | 0 |
| `./sx target test-doc-claims` | 0 |
| `./sx target test-language-deps` | 0 |
| `./sx migration` | 0 (243 / 243) |
| `./sx ci-guard` (with `RUNNER_TEMP`, `GITHUB_PATH`, `GITHUB_ENV`) | 0 |
| `./sx ci-guard-check` | 0 |

`./sx target test-sxisaexec` was re-run after every acceptance-only change and
kept passing; `./sx target test-native32` rebuilds `native_c_emitter` from
`selfhost/compiler_min.sa`, so it re-proves the C lane from source rather than
from the installed binary.

## Trust-anchor refresh

`tools/sxemit_lib.sa` is a transitive input of `tools/sxc_native.sa`, so the
native bootstrap fixed point moved. `bootstrap/sxc_native.bin` was rebuilt
through the C route, verified 3-deep (`anchor2 == anchor3`), installed, and
`bootstrap/sxc_native.audit` was regenerated by `./tools/sxaudit`. All three
manifests were re-pinned and verify with 0 FAILED.

`selfhost/compiler_min.sa` grew past its archive chunk boundary: the offline
copy in `selfhost/compiler_min_gz/` is now **151** parts (was 150).

## Honest limits

- Nested-struct fields, string fields and list fields are still **refused by
  name**, not printed. The refusal names the field, which is the difference
  between a refusal and wrong output, but it is not the feature.
- A struct returned by a call (`show f(x)`) is refused: it has no field lvalues,
  so the only C it could produce does not compile. This is pinned on the C lanes
  and refused on native_aot.
- There is no format control; the output shape is fixed at `name.field=<%g>`.
- Negative control C above shows the kind lookup's *failure mode* is silent when
  every field is numeric. A non-numeric field is the only witness.
- `basic_b64` chunk count in `docs/LINGUIST.md` said 121 while the tree held
  150; corrected to 151 here. That number is documentation, not a pinned claim.
- **R02 is not closed.** Growing lists, FP lowering across ISAs and the runtime
  API surface remain open, and **R04 (precise GC) stays open**.
