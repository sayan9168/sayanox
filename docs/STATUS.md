# Status

**2026-11-12 update: decimal negative controls in full-language tests**
The test suite `selfhost/full_language_tests/` now includes `decimal_negative_controls.sa`
and `decimal_negative_controls.want` to verify division-by-zero and 256-digit
overflow refusal in `stdlib/decimal.sa`. The `test-full-language-readiness` gate
(or `test-stdlib-next`) now pins these negative controls. This closes the gap
identified in R07/R02 regarding missing regression tests for exact decimal
arithmetic edge cases. The `selfhost/full_language_tests/README.md` has been
updated to reflect this increment. The documentation consistency increment (R01)
now tracks these files in the `test-doc-claims` suite.

**2026-11-07 (fifteenth increment) — R02 step 11: recursion is legal because
every invocation owns a frame.**

Step 10 left the call graph acyclic on purpose: a `make` body stored its
parameters in one fixed slot per parameter, so a second live invocation would
have overwritten the caller's argument while it was still needed. This increment
removes that whole refusal class by giving each invocation its own frame.

The frame, as emitted for all three targets:

* the **caller** evaluates the arguments left to right and pushes them on the
  value stack; they stay there across the call and the caller pops them after
  the return, so the result register is never clobbered;
* the **prologue** checks a shared depth word against the cap of 64, saves the
  caller's frame base in the frame, records the new base in the same data word
  (no register is dedicated — the i386 `concat` copy sequence uses every general
  register), zero-fills the body's local words and increments depth;
* the **frame slots** are `frame_base + disp` through that word, parameters at
  positive displacements and locals below the base, so `hold`/assignment inside
  a recursive body touch only the current frame;
* the **epilogue** restores the stack pointer from the frame, loads the caller's
  frame base, restores the return address, decrements depth and returns.

The bounds are unchanged in kind and now stated for recursion too: at most 8
declarations, 6 parameters, 60 words of locals per frame and 64 live frames;
the 65th call jumps to one shared overflow stub that exits 1 without writing any
output, the same contract as heap exhaustion and out-of-range indexing.

Refusals that this supersedes are gone rather than weakened:
`refuse/fn_recursion.sa`, `refuse/fn_mutual_recursion.sa` and
`refuse/fn_recursion_in_operand.sa` were deleted because those programs are
accepted now, and three bound refusals replace them:
`refuse/fn_bigframe.sa` (61 locals), `refuse/fn_many.sa` (9 declarations) and
`refuse/fn_many_params.sa` (7 parameters). The matrix stays 52 and every entry is
still an actual refusal with a line diagnostic.

**A real RV64 encoder defect surfaced while adding the fixture.** The RV64
prologue stored `ra` at `8(sp)` while the epilogue reloaded displacement `0` and
did not restore `ra` at all. One-level calls hid it: `x1` was still live at
`ret`. The first body-to-body call did not — `jal` overwrites `x1`, and the
outer `ret` jumped through an uninitialised word (`unmapped memory access at
vaddr 0` in `sxisaexec`). The prologue now stores `ra` at `0(sp)` and the
epilogue reloads it through `ld ra,0(sp)` before `addi sp,sp,16`. The previous
tool reaches `[FAIL] sxisaexec_test: fn: sxisaexec riscv64 failed`; the current
one runs `fn` and `recursion` on all six paths.

Fixtures and gates:
