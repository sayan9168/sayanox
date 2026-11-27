# `@budget` — a checked resource-budget contract on `make` declarations

Status: **specification**. This document is the rule text the implementation and
the gate's independent model are both derived from. Where this document and the
compiler disagree, this document is the authority and the compiler is wrong.

## What this is, and what it is not

`tools/native32.sa` already enforces bounds mechanically and silently: 60 words of
locals per frame, 6 parameters, 8 declarations, 64 live frames, 16-element
empty-origin list growth, and a clean `exit 1` with no output on overflow. Those
bounds are real but they are invisible in the source, and a program that trips one
finds out only by failing to compile or by overflowing at run time.

`@budget` makes the same bounds a **declared, checked contract**: the author states
the cost they designed for, and the compiler proves from statically establishable
facts that the function fits.

It is **not**:

- a general memory-safety guarantee — it bounds *frame locals*, not heap;
- a termination proof — `frames` bounds recursion depth, not whether it happens;
- WCET analysis;
- a bound on heap or RSS for the conservative collector;
- a whole-program invariant across separately compiled units.

It is a static upper bound over the constructs the current subset can cost.

## Syntax

```
@budget(frames: 8, locals: 24, lists: 16)
make isr_step(x: num) -> num { ... }
```

`@budget` appears on the line immediately before a `make` header. Keys are
`frames`, `locals` and `lists`, separated by commas, in any order. Whitespace
inside the parentheses is free. All three keys are optional individually, but an
empty `@budget()` is refused — an annotation that constrains nothing is a mistake,
not a default.

`@budget` is **erased at run time**. A satisfied program must emit byte-identical
output to the same program without the annotation, on every lane. This is a
pinned requirement, not an aspiration: the erasure proof compares images.

## Semantics

### 1. Values

Each value is a **positive integer literal**. The following are refusals:

| Form | Why |
| --- | --- |
| unknown key, e.g. `@budget(stack: 8)` | typo protection; the key does not exist |
| duplicate key, e.g. `@budget(locals: 4, locals: 8)` | ambiguous intent, not "the last one wins" |
| non-literal value, e.g. `@budget(locals: n)` | the whole point is a static fact |
| fractional value, e.g. `@budget(locals: 2.5)` | word counts are integers |
| zero, e.g. `@budget(lists: 0)` | a zero budget is indistinguishable from a typo |
| negative value | not a count |
| a value above the backend's hard cap (below) | unachievable, so refusing now beats failing later |

### 2. Hard caps

These are the mechanical limits `tools/native32.sa` already enforces. A declared
budget above any of them is a refusal.

| Quantity | Cap | Enforced today by |
| --- | --- | --- |
| words of locals in one frame | **60** | `fn_frame_words[].` bounds check |
| live frames | **64** | `fn_depth_cap` in `emit_fn_prologue` |
| elements in one list | **16** | empty-origin growth capacity |
| `make` declarations | **8** | `fn_count >= 8` refusal |
| parameters per `make` | **6** | `arity >= 6` refusal |

Note that `locals` and `lists` have hard caps of 60 and 16 respectively, so a
declared value above those is refused on the "above hard cap" rule rather than
merely failing the proven-cost comparison. This matters for the diagnostics: the
two are different errors with different messages.

### 3. What `locals` means, and how it is proved

`locals` bounds **the sum of the body's declared local words in this one frame**.

The accounting is the emitter's own accounting, and the checker **must agree with
`fn_frame_words[]` rather than replace it**. Empirically pinned against
`tools/native32.sa` (each rule below was verified by finding the exact boundary at
which the existing `a make body keeps at most 60 words of locals in a frame`
diagnostic fires):

| Construct | Words |
| --- | --- |
| `hold n = <num expression>` | **1** |
| `hold s = <str expression>` | **2** (pointer, length) |
| a `str` parameter | **2** (the prologue copies it into a local pair) |
| a `num` parameter | **0** (read in place from the caller area, no local) |
| `hold xs = [e1, ..., eN]` | **N** |
| `hold xs = []` (empty-origin, grows by `push`) | **17** = 1 name slot + the 16-word latent capacity |
| `hold s = <struct literal>` | **sum of the struct's field widths** (1 per `num`, 2 per `str` field) |
| a hidden `(pointer, length)` slot for a `show`n string result | **2** per occurrence |
| a loop counter, a `while` bound, a `when` temporary | **0** (these are not `hold` declarations) |

The **proven** cost of a function is the maximum over its body, not the sum over
nested scopes, because the emitter allocates each `hold` once into the frame and
never releases it. Dead-store elimination is not performed, so a shadowed name
costs its words twice; the checker follows the emitter here deliberately.

### 4. What `lists` means, and how it is proved

`lists` bounds **the maximum element count any single list declared in this
function may hold**.

For a list literal the count is its declared element count, exactly. For an
**empty-origin growing list** — `hold xs = []` followed by `push` — the count is
**16**, the latent capacity the emitter reserves, *not* the number of `push` calls
actually written.

Note the two different numbers, which are easy to conflate and are measured
separately by the gate:

- a growing list's **`lists`** cost is **16** (its latent capacity);
- a growing list's **`locals`** cost is **17** — the same 16 words plus the one
  word the emitter charges for the list's own name slot.

A literal list, by contrast, costs its element count in both units: each element
is one word and one place. The subset has no way to establish a tighter bound on how many
elements a growing list receives (a `push` inside a loop runs an unknown number of
times), so 16 is the number to declare. This is the one place where the checker
uses an upper bound rather than an exact count, and it is stated as such.

If a function declares several lists, the proven cost is the **maximum** of their
counts, matching the `lists` wording ("max elements any list ... may hold").

### 5. What `frames` means, and how it is proved

`frames` bounds **the maximum number of live frames reachable from this function,
including its own**.

The call graph is built from the emitter's existing call records (`call_patch`,
which holds `(site, callee)` pairs, and the `fn_names` table).

- **A cycle — direct or mutual — means the reachable depth is the 64-frame cap.**
  Any `frames` budget below 64 on a function that reaches a cycle is a
  **refusal**, not an estimate. This is the rule that keeps the contract honest:
  a static checker cannot bound a recursion whose depth depends on data, so it
  must not pretend to. The diagnostic says the function is recursive and names
  the cycle.
- **An acyclic graph gives an exact longest-path depth.** The proven `frames` cost
  of function *f* is 1 + the maximum proven cost over *f*'s callees; a leaf is 1.
  Calls to builtins (`len`, `string_eq`, `chr`, `concat`, `push`, the file
  builtins) do not add frames — they are inlined or run as shared routines outside
  the frame chain.

### 6. The callee rule

**A callee's proven frame requirement must fit the caller's declared `frames`
budget.** If `a` declares `frames: 3` and calls `b` whose proven reachable depth is
3, then reaching `b` from `a` needs 3 frames *below* `a`, i.e. 4 in total, and the
check fails.

The diagnostic **names the offending call site and both numbers** — the source
line of the call, the callee's proven depth and the caller's declared budget. A
diagnostic that says only "budget exceeded" is not sufficient.

### 7. When cost cannot be established: refuse

**When a construct's cost cannot be established statically, the compiler refuses
with a diagnostic naming the construct.** It never guesses, never rounds down, and
never warns-and-continues. The forms that reach this rule in the current subset:

- a `hold` whose right-hand side is a call to a user function returning `str` in a
  position where the hidden pair slot cannot be attributed to one frame;
- a list whose element count is data-dependent (a literal is required);
- any construct the emitter accounts differently from the table in §3 — the
  checker fails closed rather than trusting a rule it cannot verify.

An unchecked construct that silently passes is a bug in the checker, not a
lenient default.

### 8. What `@budget` may not decorate

`@budget` on anything other than a `make` declaration is a refusal: not on a
`hold`, not on a `show`, not on a `struct`, not on a bare statement, not at end of
file. An annotation floating above a non-`make` line is almost certainly a
misplaced edit, and silently ignoring it would make the contract look enforced
where it is not.

## Conformance and the gate

`./sx target test-fn-budget` runs the contract:

1. Every fixture under `selfhost/budget_tests/` compiles on every lane that can
   express it, and its stdout matches a frozen `.want`.
2. `selfhost/budget_model.sa` — a separate Sayanox program deriving expected
   `(frames, locals, lists)` from **this document's rule text alone** — must agree
   with the compiler's verdict on every fixture. The model reads the fixture
   sources; it does not read the compiler's tables or output.
3. Every file under `selfhost/native32_tests/budget_refuse/` is refused with a
   diagnostic, and the count is pinned.
4. Satisfied budgets are **erased**: a fixture with `@budget` and its twin without
   must emit byte-identical images, and every pre-existing pinned image size must
   be unchanged.

## The editor (LSP)

`tools/sayanox_lsp` reports the contract in two places, and both are gated by
`./sx target test-lsp-budget`.

**Hover** on a `make` header that has a governing `@budget`, or on the annotation
line itself, states the declared budget: `**@budget** declared: frames 8, locals
24, lists 16`. It says explicitly that the proven cost is not recomputed here.

**Diagnostics** (`SX1007`, warning severity) report only the rules decidable from
the document text:

| Condition | Message |
| --- | --- |
| key outside `frames`/`locals`/`lists` | `unknown @budget key 'stack'` |
| key repeated | `duplicate @budget key 'locals'` |
| value not a positive integer literal | `'n' is not a positive integer literal` |
| value `0`, negative or fractional | `'0' is not a positive integer literal` |
| value above the key's hard cap | `'locals' is above the hard cap of 60` |
| not on the line before a `make` | `must appear on the line immediately before a make declaration` |

The editor deliberately does **not** report a well-formed annotation whose
declared budget is too small for the function's proven cost. That verdict needs
`fn_frame_words[]` and the call graph, which belong to `native32`; a second
implementation in the editor would be an unchecked second opinion that drifts.
`test-fn-budget` proves that half, and the probe asserts that the editor counts
exactly five diagnostics on a five-defect document — a sixth would be the editor
inventing a rule.

## Limits, stated plainly

- A static upper bound over the constructs **the current subset** can cost. The
  subset is the documented native32 subset (integer expressions, static strings,
  bounded `concat`, lists, structs, functions), not the full language.
- Not a whole-program memory guarantee: two functions each within budget can still
  together exceed available memory.
- Not a termination proof. `frames: 64` on a recursive function is legal and says
  nothing about whether the recursion terminates.
- Recursion cycles are **refused below the cap** rather than analysed. A
  data-dependent recursion depth is exactly the case this contract declines to
  bound.
- Dynamic allocation beyond the fixed caps is outside the contract entirely: the
  `lists: 16` rule bounds the *declared* list, and a program that grows a list at
  run time is bounded by the emitter's capacity, not by its declaration.
- The C-output lane's allocator overhead is not counted; `locals` is frame words,
  which is a different quantity from RSS.
- The editor half is **rule-level, not cost-level**: hover restates what was
  declared, and no editor surface tells you whether the declaration is big
  enough. Only `native32` and `test-fn-budget` decide that.
- R04 (precise GC) and R02 (full native parity) remain open. Nothing here closes
  them.
