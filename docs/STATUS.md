# Status

**2026-11-13 update: Unicode text layer — UTF-8 codec and code-point text**
`stdlib/utf8.sa` and `stdlib/utext.sa` add the scalar-value layer the byte-oriented
text modules never had. Validation is strict RFC 3629: overlong forms, UTF-16
surrogates and anything above U+10FFFF are refused. `u8_sanitize` repairs with the
Unicode maximal-subpart rule (one U+FFFD per longest valid prefix), matching
Python's `errors="replace"`. `utext` counts code points, so slicing and truncation
never split a sequence, and trimming uses the exact Unicode `White_Space` set.
Two frozen fixtures carry **1,412 expectations** computed outside Sayanox from
Python's UTF-8 codec and the `White_Space` property, including randomized
malformed-byte and round-trip vectors; both match byte-for-byte on seed-min, gen2
and native_aot through `test-stdlib-next`. `examples/unicode.sa` shows a byte
slice producing invalid UTF-8 where a code-point slice does not. **Not** grapheme
clustering, normalization, display width or Unicode casing — those limits are
stated in `docs/STDLIB.md`. Two portability defects were found and fixed by the
cross-backend run: `%` inside a list literal emits invalid C on seed-min, and a
diamond `use` declares every function twice, so `utext` follows the existing
caller-composes convention. Also repaired: `docs/REMAINING_WORK.md` had 33 literal
backslash-n sequences that collapsed its work-register table into one
26,920-character line; `test-doc-claims` now pins the table shape.

**2026-11-13 update: pure-Sayanox source tree — JavaScript and Python retired**
Every tracked implementation file is Sayanox. `tools/docsite.mjs` (JavaScript)
was ported to `tools/docsite.sa` + `tools/sxdoc_lib.sa`; rendering the original
`docs/` with the Sayanox renderer reproduces the retired Node renderer's output
**byte-for-byte on all 48 files** (only the generator credit in the footer
changes), and 2,000 generated adversarial Markdown cases agreed exactly before
the JS was deleted. `selfhost/stdlib_library_pack_oracle.py` (Python) was retired
with its 1,617 expectations kept as frozen `.want` oracles. `cmd_all_sayanox` now
classifies every tracked path instead of globbing four suffixes, so a new
language cannot reappear unnoticed; `test-docsite` runs the renderer's frozen
oracles on seed-min, gen2 and native_aot and is wired into the migrated
acceptance aggregate. The Vercel CLI remains an external publishing boundary in
`docs.yml`, not tracked source. GitHub's language bar will show nothing until
Linguist registers Sayanox — see `docs/GITHUB_LANGUAGE.md`.

**2026-11-15 update: library pack — collections, graph, integer math, text, codecs, templates, money**
Ten new stdlib modules landed: `stdlib/set.sa`, `stdlib/heap.sa`,
`stdlib/intmath.sa`, `stdlib/graph.sa`, `stdlib/text_metric.sa`,
`stdlib/text_wrap.sa`, `stdlib/base32.sa`, `stdlib/net.sa`,
`stdlib/template.sa` and `stdlib/money.sa`. They provide persistent numeric
sets/heaps, checked exact integer arithmetic over `result.sa`, bounded weighted
graph algorithms, byte-string similarity and wrapping, RFC 4648 base32,
IPv4/CIDR/hostname validation, safe `{name}` templates over `map.sa`, and exact
decimal money allocation/tax/discount helpers over `decimal.sa`. Nine split fixtures carry **1,617 frozen
oracle expectations** computed outside Sayanox (Python `ipaddress`/`base64`/
`Decimal`) and pinned as `.want` bytes; all nine match byte-for-byte on seed-min,
gen2 and native_aot and are wired into `test-stdlib-next`. The generator was
retired when the repository became pure Sayanox.
`examples/library_pack.sa` is a runnable tour. This is stdlib depth, not socket
networking, Unicode-aware text, precise GC, or closure of R07. The `sx` entry and
pin manifests were refreshed for the gate change.

**2026-11-15 update: CSV dialects (TSV, semicolon, pipe)**
`stdlib/csv.sa` and `stdlib/csv_table.sa` now support an explicit delimiter byte
alongside the unchanged comma API: `csv_parse_row_d`, `csv_is_valid_row_d`,
`csv_write_row_d`, `csv_needs_quote_d`, `csv_delim_ok`, `ct_parse_d` and
`ct_write_d`. One RFC 4180 quoting engine serves comma, TAB, semicolon and pipe;
quoting is decided per dialect, so a comma is data in TSV and a tab is data in
CSV. The packed table format is delimiter-independent, so tables convert
between dialects with every cell preserved. The comma functions now delegate to
the same cores with delimiter 44, and the existing `test-stdlib-csv` and
`test-stdlib-next` oracles are unchanged and still pass.
`selfhost/stdlib_csv_dialect_test.sa` pins **473 checks** against Python's own
`csv` module on seed-min, gen2 and native_aot through `test-stdlib-next`;
`examples/csv_dialect.sa` converts one TSV export to semicolon and comma CSV.
The `sx` entry and **both** pin manifests (`bootstrap/sx.sha256`,
`docs/full-language-v1.sha256`) were refreshed for the gate change. This is CSV
dialect maturity, not a streaming parser, not Unicode-aware text, and not
JSON/CSV closure overall.

**2026-11-15 audit: the recorded gen2 condition miscompile does not reproduce**
The vNext notes recorded `while i < len(x) and f(x,i) != k` miscompiling to
`while (i < (sx_len(x) && ...))`, with a `hold n = len(x)` workaround in
`stdlib/winpath.sa`. On this tree the shape emits correct C
(`while (i < sx_len(s) && char_at(s, i) != k)`), the un-hoisted `winpath` variant
produces identical output, and a 21-check precedence sweep (comparison mixed
with `and`/`or`, user calls, inline `len()`, `and`-before-`or`) matches an
independent oracle on gen2 and native_aot. The workaround is therefore left in
place as harmless, and **no compiler fix is claimed**. The earlier observation
is not reproducible with these shapes. The sweep is now a tracked gate oracle,
`selfhost/stdlib_condition_precedence_test.sa` (21 checks), so a future change
that reintroduces the defect fails `test-stdlib-next` instead of silently
changing a loop.


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
