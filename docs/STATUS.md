# Status

**2026-11-13 update: both Unicode conformance payloads are run-time data files**

The grapheme and normalization fixtures each carried their official
conformance corpus as one enormous source literal. That cost the gen2 and
seed-min emit step on every gate run for no coverage: bytes in a literal are
not bytes in a program. Both are now read at run time --
`selfhost/stdlib_ugraph_cases.txt` (766 rows, one case per line: code points,
then expected byte offsets) and `selfhost/stdlib_unorm_cases.txt` (20,034 rows:
source, NFC, NFD) -- and both `.want` files are byte-identical to before, so
nothing about the oracle changed. The ugraph fixture's emit step fell from
about 24 seconds to 9 on gen2, half of what buys the headroom in the 90-minute
acceptance job.

**2026-11-13 update: canonical normalization — NFC and NFD**

`stdlib/unorm.sa` adds UAX #15 canonical normalization, so two spellings of the
same text compare equal. NFC composes, NFD decomposes and canonically orders,
`un_equal` answers "do these say the same thing", `un_is_nfc`/`un_is_nfd`
answer "is this already in that form", and the list API (`un_nfc_list`,
`un_nfd_list`, `un_ccc`, `un_decomp`, `un_compose_pair`, `un_excluded`) exposes
the tables directly. Verification is **1,544 expectations**: the depth fixture
runs **all 20,034 cases of the official Unicode 17.0.0 `NormalizationTest.txt`**
through the real NFC/NFD and adds an API layer checked against an independent
Python reference that reproduces every column of those 20,034 rows before any
expectation is frozen, and the compact companion carries the same rules to the
bounded `native_aot` profile — **all four backends** on one oracle. The payload
is a 588 KB run-time data file rather than a literal, which took the gen2 build
from minutes to four seconds. Four negative controls confirm coverage rather
than assuming it: disabling canonical ordering changes 4 expectations, the
blocked-mark test 4, Hangul composition 10, and one-step-only decomposition 6;
each module version was restored byte-exact afterwards. Building it also
re-found a real rule: composition must try the pending starter for starters as
well as marks, because 961 pairs include 59 whose second element has combining
class 0 (Indic vowel signs such as U+0B47 + U+0B3E), and blocking must be
decided by the last *non-composing* mark, not by the last character seen. The
first version of both was wrong and the official file is what caught it.
`examples/normalization.sa` is a runnable tour and agrees on gen2, native_aot
and the full native compiler. **Not** case folding, collation or
bidi — those limits are stated in `docs/STDLIB.md`, and R07 stays open.

**2026-11-13 update: Unicode casing — upper, lower, title and case folding**

`stdlib/ucase.sa` adds UAX #44 default case conversion, so text can be
uppercased, lowercased, titlecased and case-folded the way Unicode means it
rather than the way ASCII means it. One code point may map to several:
`uc_upper("ß")` is `SS`, `uc_title("ß")` is `Ss`, `uc_upper("ﬁ")` is `FI`, and a
Greek iota-subscript form uppercases to two code points. `uc_fold` is case
folding, a different operation from lowercasing (`uc_lower("ß")` is unchanged,
`uc_fold("ß")` is `ss`), and `uc_fold_equal` is the caseless comparison built on
it, alongside the two UAX #44 properties `uc_cased` and `uc_case_ignorable`.
Verification is **4,241 expectations** in two fixtures: the depth fixture pins
one row per simple-casing group (read back out of the module's own compressed
table, not just its effect), every one of the 1,585 case folds, all three
directions of all 103 unconditional `SpecialCasing` entries, the shape of the
four packed tables, and the property, invariant and failure-contract sweeps; the
57-expectation compact companion carries the same rules to the bounded
`native_aot` profile, so all four backends answer to one oracle. The tables come
from `UnicodeData.txt`, `SpecialCasing.txt` and `CaseFolding.txt` themselves, and
the independent Python reference is cross-checked against CPython's tables on
206 mapping directions and 1,530 folds before anything is frozen — which caught
a real bug: `SpecialCasing.txt` writes `lower; title; upper` while
`UnicodeData.txt` writes `upper; lower; title`, so the parser had `ß` and `İ`
swapped until the cross-check failed. **Not** modelled, deliberately: the sixteen
conditional entries (Turkish/Azeri dot rules, `Final_Sigma`, Lithuanian, Dutch
`ij`), `NFKC_Casefold`, sentence titlecasing and collation. `examples/casing.sa`
is a runnable tour and agrees on gen2, native_aot and the full native compiler.
NFKC/NFKD, bidi, collation and streaming CSV stay open, so R07 stays open.

**2026-11-13 update: native32 string parameters and string-valued functions**
The multi-ISA machine-code backend (`tools/native32.sa`, i386/AArch64/RV64IM)
accepted only `num` parameters and `num` results. A parameter may now be
`name: str` and a body may return `-> str`, including a mixed `num, str, num`
list. A string is a `(pointer, length)` pair and so occupies two pushed words
where a num occupies one; every parameter displacement is computed from those
widths. Because a 64-bit push is 16 bytes while a pair's fields are 4, the
prologue copies each string argument into a compact local pair instead of
reading it in place. A `-> str` body publishes one shared absolute pair that the
caller copies out before any other call can run, which makes `f(g(x))` and
recursion sound with a single slot. Three new fixtures agree byte-for-byte on all
**seven** distinct execution paths across the two ISA gates (seed-min, gen2,
native_aot/x86-64, the IR virtual machine, i386, AArch64, RV64IM) with
reviewed ARM64/RV64 goldens and pinned i386 sizes; the refusal matrix grew
52 -> 64 and two old refusals became legal programs. Every pre-existing golden
and all eleven pinned i386 sizes are unchanged. Three real defects surfaced:
a `-> str` call as a numeric operand was silently accepted, a returned literal
lacked the trailing newline `show` writes, and the result copy used the frame
store path for an absolute destination inside a body, losing every nested
result. **R02 is not closed:** aggregates, FP, file/runtime APIs, GC and `concat`
in general expressions remain open.

**2026-11-13 update: grapheme clusters and display width — the reader's unit**
`stdlib/ugraph.sa` implements UAX #29 extended grapheme clusters (GB1–GB999,
including the Unicode 15.1 Indic conjunct rule GB9c, the emoji ZWJ rule GB11 and
GB12/13 regional-indicator pairing) and `stdlib/uwidth.sa` answers the separate
question of terminal columns (0 for `Mn`/`Me`/`Cf`, 2 for East Asian `W`/`F`, 1
otherwise, Ambiguous treated as 1). A cluster count now says one for क्ष, for a
Hangul L+V+T syllable and for a family emoji, where the code-point layer says
three, three and five. Slicing, reversing and truncation are expressed in cluster
boundaries, so no operation can strand a combining mark or half a flag.
Verification is **5,463 frozen expectations** in three fixtures: all **766 cases
of the official Unicode 17.0.0 `GraphemeBreakTest.txt`**, a sweep of **all
1,114,112 code points** through the real bisection for width and for the
class/`Extended_Pictographic`/`InCB` lookups (frozen as run-length transitions, so
a million checks cost about a thousand oracle lines), and the cluster/text API
against an independent rule-regex reference that is itself proven against all 766
official cases first. The two large fixtures exceed `native_aot`'s bounded 64-slot
profile, so a 61-expectation compact companion runs on **all four** backends;
the large ones match on seed-min, gen2 and the full native compiler through
`test-stdlib-next`. Tables are generated from the Unicode 17.0.0 UCD files
themselves, not from a host library — and that mattered: the `regex` module
reports `East_Asian_Width=W` for *every* unassigned code point, so a table built
from it wrongly gave two columns to 814,042 scalars until the whole-range sweep
caught it, and neither
`regex`'s `\X` nor `uniseg` passes the official conformance file (16 and 9
failures). Three negative controls confirm the oracles bite: disabling GB9c
changes 8 expectations, breaking the bisection midpoint back to exact `/` changes
835, and dropping the GB11 picture flag across ZWJ changes 18 including official
cases 741–743; each module was restored byte-exact afterwards. One portability
defect was found by the cross-backend run and fixed: gen2 rejects `give` and `}`
on the same source line, so the 17 one-line class-constant bodies in `ugraph.sa`
were expanded. `examples/graphemes.sa` is a runnable tour and agrees on gen2,
native_aot and the full native compiler. **Not** normalization (NFC/NFD), bidi,
collation or Unicode casing — those limits are stated in `docs/STDLIB.md`.

**2026-11-13 update: Unicode text layer — UTF-8 codec and code-point text**
`stdlib/utf8.sa` and `stdlib/utext.sa` add the scalar-value layer the byte-oriented
text modules never had. Validation is strict RFC 3629: overlong forms, UTF-16
surrogates and anything above U+10FFFF are refused. `u8_sanitize` repairs with the
Unicode maximal-subpart rule (one U+FFFD per longest valid prefix), matching
Python's `errors="replace"`. `utext` counts code points, so slicing and truncation
never split a sequence, and trimming uses the exact Unicode `White_Space` set.
Two frozen fixtures carry **1,447 expectations** computed outside Sayanox from
Python's UTF-8 codec and the `White_Space` property, including randomized
malformed-byte and round-trip vectors; both match byte-for-byte on seed-min, gen2
and native_aot through `test-stdlib-next`. `examples/unicode.sa` shows a byte
slice producing invalid UTF-8 where a code-point slice does not. **Not** grapheme
clustering, normalization, display width or Unicode casing — those limits are
stated in `docs/STDLIB.md`. `ut_index_of`/`ut_count` walk byte boundaries in a single pass: the
first version re-sliced from byte 0 per candidate, which took 7.6 s on a 6 KB
string and would have been minutes at the 64 KiB cap; the same search now takes
0.014 s with identical output, pinned by boundary-alignment and non-overlapping
count cases. Two portability defects were found and fixed by the
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
