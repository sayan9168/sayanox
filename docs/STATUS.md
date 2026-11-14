# Status

**2026-11-13 update (second increment): mature exact-decimal surface**
`stdlib/decimal.sa` now provides a complete exact-decimal API beyond the earlier
add/sub/mul/div/round core: `dec_abs`, `dec_sign`, `dec_is_zero`,
`dec_is_negative`, `dec_is_integer`, the ordering predicates `dec_eq`/`dec_lt`/
`dec_le`/`dec_gt`/`dec_ge`, `dec_min`/`dec_max`, `dec_trunc`/`dec_floor`/
`dec_ceil`, `dec_mod` (truncated-division remainder with the dividend's sign),
`dec_pow` (exact integer power by repeated squaring), and `dec_to_fixed` (round
then pad to exactly N fractional digits for money/display). All reuse the exact
digit primitives, never convert through IEEE doubles, and keep the 256-digit
bound. `selfhost/stdlib_decimal_mature_test.sa` pins **201 checks** against an
independent Python-`Fraction` oracle on seed-min, gen2 and native_aot through
`./sx target test-stdlib-next`; `examples/decimal_money.sa` shows an invoice that
splits to the exact cent. Irrational/transcendental ops are explicitly out of
scope. The `sx` entry and `bootstrap/sx.sha256` were rebuilt/reviewed for the gate
change; `./sx verify-entry` passes. This matures the decimal third of R07; it is
not JSON/CSV closure, precise GC, or complete guarded CI.

**2026-11-13 update: vNext stdlib, executable decimal controls, and LSP completion**
`stdlib/result.sa`, `stdlib/deque.sa`, `stdlib/fs_safe.sa`, `stdlib/task_pool.sa`
and `stdlib/winpath.sa` add explicit numeric results, a persistent ring deque,
checked filesystem helpers, a bounded child-process pool, and lexical
Windows/POSIX path helpers. `selfhost/stdlib_vnext_test.sa` runs the portable
subset on seed-min, gen2 and native_aot; `selfhost/stdlib_vnext_io_test.sa` runs
the filesystem/process subset on gen2 and the full native compiler. Both are
wired into `./sx target test-stdlib-next` with byte-for-byte oracles.

The earlier decimal-negative-control claim was not executable: the fixture used
nonexistent `decimal_*` aliases and was not run by the named gate. It is now
rewritten against the real `dec_*` API and executed by `test-stdlib-next` on
seed-min, gen2 and native_aot. This is a focused regression repair, not closure
of R07 or full guarded CI.

LSP completion now adds document/import symbols and namespaced module members
with prefix filtering, while preserving the standard keyword/builtin list.
`test-lsp-ide` pins module-member completion and prefix filtering. The checked-in
`sx` entry and `bootstrap/sx.sha256` were rebuilt/reviewed for the gate change;
`./sx verify-entry` and `./sx doctor` pass on this source.

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
