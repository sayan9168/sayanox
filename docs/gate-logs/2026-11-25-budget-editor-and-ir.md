# `@budget` in the editor, and erasure in the IR

Two increments that close the two places the `@budget` increment (PR #113)
declared but did not deliver. Both were verified as genuinely absent on `main`
before any code was written:

```
$ git grep -c "budget" origin/main -- tools/sayanox_lsp.sa
tools/sayanox_lsp.sa:1        # and that one match is `within BOUND`, not @budget
$ git grep -c "budget" origin/main -- tools/emit_to_ir.sa tools/sxirexec.sa
(empty)
```

Branch: `arena/9a8509bd-sayanox`, on top of `main` at `2f0d23a`.

## 1. IR erasure

`docs/BUDGET.md` requires a satisfied annotation to be byte-invisible "on every
lane". Three image comparisons already proved the native32 lanes. The IR lane was
never checked, and it is the one lane whose listing is derived from
`native_aot`'s `SX_EMIT_LOG` rather than from `native32` at all — so an erasure
implemented only in the multi-ISA checker would leave the annotation visible
there and nothing would notice.

New gate code, `bg_ir_erasure()` in `tools/sxbudget_gates_lib.sa`:

```
SX_EMIT_LOG=<log> ./selfhost/native_aot <src> <elf>
./tools/emit_to_ir <log> > <ir>
```

Two fixtures are lowered — `plain.sa` (no annotation) and `plain_twin.sa` (the
same program with a satisfied `@budget`) — and the instruction streams are
compared.

### What the first attempt got wrong

The first version compared the two `.ir` files whole, and it failed:

```
[FAIL] IR listing must not carry an erased @budget (ir_plain.ir != ir_twin.ir)
$ diff ir_plain.ir ir_twin.ir
4c4
< ; native_aot instruction list for selfhost/budget_tests/plain.sa
---
> ; native_aot instruction list for selfhost/budget_tests/plain_twin.sa
```

The only difference was the banner naming the *input file*. The annotation itself
was already erased — `grep -c '@budget'` returned 0 in both listings. That is a
fixture bug, not a compiler bug, and the distinction mattered: a whole-file
comparison of two files named differently can never pass, so this assertion would
have been permanently red and someone would have "fixed" it by deleting it.

The comparison now starts at emit_to_ir's `; offset  instruction` marker, so it
compares the instruction stream and not the banner.

### Assertions actually made

| Assertion | Why it is needed |
| --- | --- |
| instruction streams are identical | the erasure claim |
| `@budget` does not appear in the stream | the annotation as a word, not just as a diff |
| the stream is at least 64 bytes | a listing truncated to nothing would pass the first two |
| two *different* programs produce *different* streams | a constant-emitting `emit_to_ir` would pass all three |

**Negative control.** Pointing the twin at `chain1.sa` instead of `plain_twin.sa`
makes the first assertion fire:

```
[FAIL] IR instruction stream must not carry an erased @budget: string mismatch
```

## 2. Hover and diagnostics

### The divisions of labour that constrain the design

The LSP cannot recompute the proven cost. Doing so would need `fn_frame_words[]`
and the `call_patch` graph, which belong to `native32`; a second implementation in
the editor would be an unchecked second opinion free to drift from the checker it
is supposed to describe. So the editor does **rule-level** work only:

- **hover** restates what was declared;
- **diagnostics** (`SX1007`) report only what is decidable from the document text.

A well-formed annotation whose declared budget is too small is **not** an editor
diagnostic. `native32` owns that verdict and `test-fn-budget` proves it. The
probe asserts this in the negative — see the count assertion below.

### Six defects, five diagnostics, one placement rule

A six-defect document is opened and its `textDocument/diagnostic` reply inspected:

| Line | Annotation | Reported |
| --- | --- | --- |
| 0 | `@budget(frames: 8, locals: 24, lists: 16)` | nothing (valid) |
| 4 | `@budget(frames: 8, stack: 4)` | `unknown @budget key 'stack'` |
| 8 | `@budget(locals: 99)` | `'locals' is above the hard cap of 60` |
| 12 | `@budget(locals: 4, locals: 8)` | `duplicate @budget key 'locals'` |
| 16 | `@budget(locals: n)` | `'n' is not a positive integer literal` |
| 20 | `@budget(locals: 0)` | `'0' is not a positive integer literal` |

Five, not six: the sixth rule (annotation not followed by `make`) needs its own
document, which the ad-hoc check below covers. The probe asserts the count is
**exactly five** — a sixth would mean the editor invented a rule the compiler does
not have.

### The count had to be scoped to the reply

First version counted `SX1007` across the whole output and got 10. That is
correct behaviour, not a bug: the same five diagnostics are also pushed through
`textDocument/publishDiagnostics` on `didOpen`. The count is now taken only after
`"id":52`, the diagnostic reply.

### The zero case was silently accepted

`is_positive_int("0")` returned 1 on the first attempt, so `@budget(locals: 0)`
produced no diagnostic — the one rule in the table above that the editor's own
helper contradicted. Fixed by rejecting a leading `0` before the digit scan:

```
when sx_index(t, 0) == 48 { give 0 }
```

Caught by opening the six-defect document and reading the reply, not by reasoning
about the helper.

### Hover fires on the line, not the word

The first implementation sat after `hover_typed`'s existing early return:

```sayanox
when len(doc) <= 0 || len(w) <= 0 { give hover_for(w, doc) }
```

so a cursor in the whitespace of a `make` header — where there is no identifier
under it — never reached the budget block. The budget belongs to the **line**, not
to the word, so the block now runs before that check, and the word check follows
it.

### Negative control

Replacing `hold bl = budget_line_for(doc, ln)` with `hold bl = 0 - 1` restores the
pre-increment behaviour exactly, and the probe reports:

```
[FAIL] budget hover names the declared keys (missing **@budget** declared: frames 8, locals 24, lists 16)
```

## Gate wiring

New target `test-lsp-budget`, in all three places:

| File | Change |
| --- | --- |
| `tools/sxlsp_gate_lib.sa` | `rt_lsp_probe` row with the exact expected output |
| `tools/sxrunner_targets_lib.sa` | `rt_known()` and the dispatch block |
| `tools/sxmigration_lib.sa` | registry |
| `tools/sxaggregate_targets_lib.sa` | `ag_native_before()` |

Migration coverage **242 / 242 → 243 / 243**.

This is the same class of defect PR #114 fixed: a target that exists but is not
reachable. `target_known()` consults `rt_known()`, so adding the dispatch block
alone left `./sx target test-lsp-budget` failing with

```
sxbuild: target not migrated (no make fallback): test-lsp-budget
```

until the name was registered in `rt_known()` as well.

## Expectation counts

| Check | Count |
| --- | --- |
| `test-fn-budget` accepted fixtures | 12 (unchanged) |
| `test-fn-budget` refusals | 22 (unchanged) |
| `test-fn-budget` new IR assertions | 4 |
| `test-lsp-budget` assertions | 8 |
| `test-lsp-budget` diagnostics expected | exactly 5 |

No refusal count changed. `refuse` stays 105, and the pinned i386 sizes for `fn`,
`recursion`, `list_expr`, `strfn`, `chr`, `strrec` are unchanged.

## Negative controls, and the row that caught each

| # | Break | Row that caught it |
| --- | --- | --- |
| g | IR twin pointed at a different program | `IR instruction stream must not carry an erased @budget: string mismatch` |
| h | hover's budget lookup disabled | `budget hover names the declared keys` |
| i | `is_positive_int` accepting `0` | `budget diag zero` (and the exact-five count) |

## Honest limits

- The editor half is **rule-level, not cost-level**. No editor surface tells you
  whether a declaration is large enough; only `native32` and `test-fn-budget`
  decide that, and hover says so in its own text.
- `@budget` is still checked only by `native32`. The IR lane is now proven to
  *erase* it, not to check it.
- The IR assertion is a **comparison**, not a decoder. It proves the two
  instruction streams agree; it does not prove the stream is a correct lowering of
  the source.
- A `make` header with **no** governing annotation gets no hover from this
  feature; it falls through to the pre-existing behaviour.
- R04 (precise GC) and R02 (full native parity) remain open.
