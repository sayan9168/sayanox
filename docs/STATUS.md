# Status

**2026-11-25: checked resource-budget contract (`@budget`)**

`@budget(frames: 8, locals: 24, lists: 16)` on the line before a `make` declares
a compile-time upper bound. `tools/native32.sa` checks it against the two facts it
already owns -- `fn_frame_words[]` for locals and the `call_patch` graph for
frames -- so the accounting agrees with the emitter instead of replacing it, and
never guesses: any cost it cannot establish is a line-numbered refusal.

Measured accounting, bisected before the checker was written: a `str` costs 2
words, a `num` 0, a list literal one word per element, and an **empty-origin
growing list 16 for `lists` but 17 for `locals`** (the latent capacity plus its
name slot). That last distinction was wrong in the first draft of
`docs/BUDGET.md` and in the independent model -- the compiler was refused by its
own spec, the spec was corrected, and both now agree on every fixture.

**Frames.** `native32` already had a 64-deep call guard; §2 turns it into a
stated rule: any recursion cycle makes reachable depth the cap, so a recursive
function declaring `frames` below 64 is refused, and an acyclic chain is costed
exactly (a leaf reaches 1). A callee's own requirement is charged to the caller
through the call site, and the diagnostic names the callee and both numbers.

**Erasure.** The annotation is removed before any parser sees it, at four
separate choke points: `selfhost/modules/compiler_text.sa` for the C lanes,
`tools/sxinfer_lib.sa` for `native_aot` and `sxc_native`, and `tools/sxdefs.sa`
(plus `tools/native32.sa`). All four substitute a comment rather than deleting the
line, so line numbers in diagnostics and line tables are unchanged. `plain` and
`plain_twin` are byte-identical on every lane, the six-way gate covers AArch64 and
RV64IM, and the four pre-existing i386 pins (`fn` 8265, `recursion` 8259,
`list_expr` 8252, `strfn` 8608) are unchanged.

**Evidence.** New gate `./sx target test-fn-budget`: 12 accepted fixtures on three
ISAs with frozen `.want`, a determinism rebuild and cross-ISA data equality each;
22 refusal fixtures with 22 named diagnostic rows; the model gate bisects the
compiler's own verdict to recover the proven cost and requires
`selfhost/budget_model.sa` to agree on locals and lists for every fixture. Cross-lane
parity runs the same `.want` on seed-min, gen2, `native_aot`, `sxc_native` and the
IR VM; `test-sxisaexec` adds six-way rows for i386/arm64/riscv64. Six negative
controls each flip a named row, and `tools/native32.sa` was restored byte-exact
(`ad75a1c0…`). See [the gate log](gate-logs/2026-11-25-fn-budget.md).

**Honest limits.** This is a static upper bound over the constructs the current
subset can cost. It is not memory safety, not termination, not WCET, and not a
heap/RSS bound for the conservative collector: allocation beyond the fixed caps
and C-lane allocator overhead are outside it. Recursion cycles are refused rather
than analysed. **R04 (precise GC) and R02 (full native parity) stay open**, and
`@budget` is checked only by `native32` -- on the other lanes it is erased and an
unsatisfied annotation is not reported.

**2026-11-24 local R20 increment: `SMULH`/`UMULH` decode and the RV64 64-bit M extension**

The AArch64 3-source multiply group decoded `SMULH` as `SMADDL`: block 5 tested
bit 23 where the discriminator is bit 22, so `SMULH x10, x7, x8` multiplied the
two 32-bit halves and answered bits 63:0 of the product where the architecture
asks for bits 127:64. `UMULH` was refused outright. Both now decode through
`a64_mulh` on bit 22 with `Ra == 11111` and `sf == 1`; `op31 = 011 / 100 / 111`
are refused explicitly by clauses that keep `op31 = 101` (`UMADDL`) working.
R20 item 4 was originally written as "refuse the shape" -- the probe showed these
are real instructions with a silently wrong answer, so the increment decodes them,
and **no refusal-matrix count moves**.

The same fixture covers RV64, which had no 64-bit M-extension at all: `rv_m64`
and `rv_div64` implement `MUL`/`MULH`/`MULHSU`/`MULHU` and
`DIV`/`DIVU`/`REM`/`REMU`, with an RV64 twin image covering `MULH`, `MULHU`,
`MUL`, `DIVU`. The AArch64 image pins 7 rows across all four sign combinations
(a wrong sign rule cannot pass adjacent rows); the unallocated control pins 5
refused shapes, each image ending in a real `exit(0)` so acceptance is
observable. Seven deliberate breaks were applied and each was caught by a named
row. Three of the seven did not fire on their first attempt -- one because the
fixture had no negative `Rm`, one because "accepted then fell off the end" and
"refused" both exited non-zero, and one because the RV image exited 0
unconditionally -- and the fixture was corrected each time rather than the control
being recorded as passing. Those two RV defects (`rv_m64` transposing the high
half, `signd` inverted so `DIVU`/`REMU` read as signed) were found by making the
probe falsifiable and never shipped. See
[the gate log](gate-logs/2026-11-24-aarch64-multiply-high.md).

Still open on R20: `MULHSU`/`DIV`/`REM`/`REMU` share exercised code paths but no
row names them directly, the 32-bit `MULW`/`DIVW`/`REMUW` words are unchanged,
and item 3 (per-case FP arithmetic probes) is untouched.

**2026-11-24 main CI repair: native32 global budget and full-contract pins**

`tools/native32.sa` had 66 module-level `hold` declarations after the file-I/O
increment, above native_aot's 64-variable phase-1 limit. That made
`test-native-sxdefs` fail before it could write `expand.sa`, which in turn
failed `test-driver` in the clean no-Makefile integration and both CI jobs on
`main`. Seven state holders are now scoped to where they are used: the four
`string_eq` placement words and the final unused `rc` live only in `run()`,
`fn_depth_cap` is local to `emit_fn_prologue`, and the two call-patch lists are
one flat `[site, fn, ...]` list. The module now has 59 top-level holders and
emits byte-identical i386/AArch64/RV64 images. `test-native-sxdefs`, the three
ISA gates, `test-sxisaexec` and fresh `test-driver` (including the no-Makefile
nested chain) pass; the failing pre-fix gate is the regression control.

The second CI failure was `true-selfhost-full`: `docs/full-language-v1.sha256`
still pinned six pre-increment files (`REMAINING_WORK.md`, `native32.sa`,
`sxenc_lib.sa`, `sxisa_gates_lib.sa`, `sxisaexec.sa`, `sxisaexec_test.sa`), so
`sxfull verify` failed. The six rows and the manifest's own row in
`bootstrap/sx.sha256` are refreshed to the current accepted sources; both
manifests and `sxfull verify` now pass. This is a pin refresh, not a change to
the published-language v1 clause inventory. The long full-acceptance chain was
still running without a failure when this note was written; guarded remote CI
remains the final proof.

**2026-11-23 local R02 increment: `read_file`/`write_file` on the three native32
targets, AArch64 ISA coverage in `sxisaexec`, and the 64-bit divide that coverage
exposed**

`tools/native32.sa` lowers the two file builtins into the target's own Linux
syscall ABI -- `openat`, one `read` or `write`, `close` -- behind one lazily
reserved 4129-byte data block and one shared routine per builtin placed after the
`make` bodies, so arguments and results never touch the value stack, a program that
does not name a builtin emits neither the block nor the routine, and the data
segment stays arch-neutral (R14). `write_file` answers
`(count == len) && (close == 0)`; `read_file` does one bounded 4096-byte read and
returns the span up to the first NUL, which is the span rule every other string
value in the dialect already follows, and a failed open answers the empty string.
Two shapes are refused instead of approximated: a variable path (the NUL has to be
pooled with the literal) and a numeric text. `selfhost/native32_tests/file_io.sa`
runs on all six execution paths with an independent `.want`, reviewed AArch64 and
RV64IM goldens and a pinned 12735-byte i386 image, and both refusals are in
`refuse/`. Getting there needed the emulator: on `main`, `tools/sxisaexec.sa`
refused most of the AArch64 forms the file-I/O lowering emits and computed wrong
answers where it did decode. Each area was settled by running one instruction and
comparing the emulator against QEMU user-mode ARM64 (Unicorn) and a hand-written
expectation, with emulator-vs-QEMU as the arbiter -- three of those expectations
were the wrong column. Added now: `SBFM`/`UBFM`/`BFM`/`EXTR` (with `EXTR`'s 6-bit
amount at 15:10 and `Rn` as the high half of the pair), the full
`CSEL`/`CSINC`/`CSINV`/`CSNEG` group at both widths and their
`CINC`/`CNEG`/`CSET`/`CSETM` aliases, `FMOV` between the general and FP registers,
`FCVTZS`/`FCVTZU` at all four shape combinations with saturation, `LDRH`/`LDRSH`/
`LDRSB`/`LDRSW`, `BR`/`BLR`/`RET` and `ADR`/`ADRP`. Fixed in what `main` did decode:
its 3-source block multiplied the low halves only and zero-extended, so a 64-bit
`MADD` lost everything above 2^32 and `SMADDL` was indistinguishable from `UMADDL`
(the pair-domain helper this replaces had its own trap -- folding the carry out of
bit 63 back into the high word answers `(-2) * (-4)` = `00020000_00000008`),
`LDR S` filled `V<n><63:32>` with ones instead of zeroes, and `CSETM` was swallowed
by the `CSINC` shape and answered `+1`.
Unallocated shapes *inside* decoded groups (the 3-source base, out-of-range bit-field
immediates, `EXTR` with o1 set) now refuse instead of executing; refusal of words no
decoder claims was already in place and was re-checked against twelve such encodings.
71 single-instruction probes in six images, each seeding its own registers and
accumulating a mismatch count in `w20`, are committed as image builders in
`tools/sxisaexec_test.sa`; seven deliberate breaks of the decoders each make exactly
one image fail, so the probes are not passing by construction. Running the six
images against the `main` build is itself the regression evidence: it refuses at the
first `LSR`-as-`UBFM`, the first 64-bit `CSEL`, the first `LDRH`, the first
`FMOV` and the first `ADRP`, and finishes the multiply image with six of nine probes
wrong. `tools/sxisaexec.sa` also compiles under `SXBUILD_VIA_C=1` now, which `main`
does not: two registers were held inside one `when` branch and read after it. `test-sxisaexec`,
`test-native32`, `test-native-arm64` and `test-native-riscv64` pass, and
`./sx migration` reports 241/241.

The coverage work then found a silently wrong answer rather than a missing one: the
emulator executed `UDIV`/`SDIV` through the 32-bit path at *both* widths, accepting
the word and returning a wrong quotient above 2^32. `a64_div`/`a64_sdiv` now divide
in the `(lo, hi)` pair domain, pinned by 25 rows that the gate itself generates from
a hex table and checks against an independent limb model, with 15 deliberate breaks
of the divide path each caught by a named row. See
[the divide gate log](gate-logs/2026-11-23-aarch64-64bit-divide.md). What stays open
is named in R20 (per-case FP arithmetic probes, and the RV64 forms that no row
names directly -- `SMULH`/`UMULH` and the 64-bit RV64 M extension were closed on
2026-11-24) and in R02
(structs, growing lists, FP lowering, GC). See
[the coverage gate log](gate-logs/2026-11-23-arm64-isa-coverage.md).

**2026-11-22 local R07 increment: INI/TOML-lite configuration, gated by an independent oracle**

`stdlib/ini.sa` reads a `.ini`/`pyproject`-shaped document into a packed
`stdlib/csv_table.sa` table of (section, key, value) and writes one back out: 22
entry points over the 19 rule helpers they are built from, under nine documented
rules - LF and CRLF alike, `;`/`#` commenting a whole line and never part of a
value, `[name]` headers refused when empty because the default section is spelled
by writing its members first, the first `=` splitting a member line, exactly five
escape pairs inside a quoted value, a repeated key or section refused instead of
resolved, and `ini_max_bytes()` (65536) on top of the csv_table caps - with
malformed text answered by chr(33) rather than a partly-parsed table and
`ini_write` quoting a value exactly when its raw bytes would not survive those
rules. It is pinned by two frozen fixtures whose expected bytes were computed by
a host-side model written from that rule text and never from a Sayanox run
(`selfhost/stdlib_ini_test.sa` with 1,026 expectations and
`selfhost/stdlib_ini_write_test.sa` with 335), every accepted document re-parsed
by Python's `configparser` (32 of 33 agreeing member for member, the one
divergence the documented default section). Two files because bounded
`native_aot` pays one variable slot per top-level name and one patch slot per
call site and the single fixture passed neither limit. Writing the oracle also
measured a cost that keeps one boundary out of the pins: `ini_parse` checks every
new member by scanning the table built so far, which the table-as-a-string
representation copies as it walks, so the check is cubic in members (0.52 s at
32, 3.60 s at 64, 26.09 s at 128) and a document large enough to reach the
csv_table 1,024-row cap never finishes - the row cap stays pinned where it is
imposed, and linearizing the member check is open work on this module rather than
a claim this increment makes. `test-stdlib-next` runs both halves on seed-min,
gen2, `native_aot` and `gen1_min` and requires all four to match the pinned bytes
and each other, and six negative controls (header-row scan reading row 0,
`ini_valid` ignoring its marker, the writer's quote clause disabled, a carriage
return left undecoded, `ini_set` appending a default member behind every section,
`ini_has_header` made unconditional) each make a family fail. Stdlib depth (R07)
stays open: inline comments, value types, multi-line values, TOML tables and
arrays and comment-preserving edits are not modelled.

**2026-11-21 local R07 increment: CSV dialect sniffing and JSON path creation**

Two stdlib gaps closed with frozen independent oracles. `stdlib/csv.sa` now
answers which single-byte delimiter a sample was written with
(`csv_sniff`, `csv_sniff_list`, `csv_parse_row_sniff`, plus the `csv_sep_count`,
`csv_line_cut`, `csv_first_line` and `csv_sniff_lines` pieces they are built
from): a mechanical rule over at most 4096 bytes and 64 non-empty lines,
unquoted-separator agreement on every line, the densest candidate winning, ties
kept in candidate order, and an explicit `-1` for a one-column or ambiguous
sample instead of a guess. `stdlib/json_deep.sa` gained `jd_put_raw`, which
creates the containers a dotted path is missing and sets the leaf, inferring
array versus object from whether the segment is all digits, refusing sparse
index creation and every scalar-in-the-way case with `""`, and leaving unrelated
bytes untouched. Both are pinned by new fixtures whose expected bytes were
computed outside Sayanox - `selfhost/stdlib_csv_sniff.want` (106 rows) and
`selfhost/stdlib_json_put.want` (116 rows) - and `test-stdlib-next` now requires
seed-min, gen2, `native_aot` and `gen1_min` to produce those exact bytes and to
agree with each other. Sniffing rows are additionally cross-checked against
Python's `csv` module with seven documented divergences, all of them
unterminated-quote inputs this codec refuses by contract. Stdlib depth (R07)
stays open; this is two more operations, not a closed data layer.

**2026-11-21 local R08 increment: three published packages, one index-driven registry gate**

`registry/` published three more packages - `text`, `numfmt` and `kv`, the last
depending on the first - and `test-registry-sums` was rewritten to read
`registry/INDEX` instead of a package list hard-coded inside the gate. It now
checks `pkg.meta` name/version/sum against the tree, re-derives every `sum=`
with `sxpkg sum`, refuses a `registry/` directory that is missing from the
index, and compiles and runs a one-line probe per package with gen2 from inside
a project holding its own `.sayanox/registry` copy, so a package that no program
can build - or that reaches for a helper it never declared - fails here. The
gate caught one of its own wrong expectations (`pkgtext_words("a bb  c")` is 3,
not 2) before it caught any code, and three negative controls (index entry with
no package, package directory outside the index, tampered `sum=`) each fail it.
Authenticated transport, key distribution and trust roots (R08) are untouched
and stay open.

**2026-11-19 local R02 increment: string-field initializer parity**

A bounded change allows `Row { ..., a.text }` in gen2 and defers unresolved
string-field types during x86-64 inference until the strict pass. Numeric
selector initializers remain a separate documented refusal. The expanded
independent oracle covers top-level and function-local copies; unknown fields,
wrong kinds and non-struct selectors have explicit refusal fixtures. The
native compiler was rebuilt at a compiler2/compiler3 fixed point with unchanged
688128-byte size; this is not independent trust evidence. Acceptance for this
increment passed fresh `true-selfhost`, `gen3`, `test-struct-string`,
`test-native32`, `test-native-arm64`, `test-native-riscv64`, `test-sxisaexec`,
`test-native-sxinfer` and `test-generic-structs` gates, with the mandatory i386,
IR and full-native oracles. Repeatable i386 images have a pinned size of 8328
bytes and ARM/RV goldens are checked. Full CI for this increment is pending.

Before this change, the fresh local `./sx ci` for the string-index increment
completed successfully, including published-language v1 acceptance. This does
not establish remote guarded CI or full native parity.

**2026-11-19 local R02 increment: string-field byte indexing**

The seed and gen2 C emitters now use the typed postfix walker for string-field
indexes, including `hold` and `show`; previously `show` silently discarded the
index and `hold` was refused. The independent byte oracle exercises variables,
arithmetic and a function-local index on seed, gen2, both x86-64 compilers, the
IR VM and all three native32 ISAs. Wrong-type and unclosed indices are refused; high and low bounds faults exit 1
without output. The native32 expression parser now also rejects an unmatched
opening bracket.
Repeatable i386 images have a pinned size and ARM/RV images have goldens. The
C lanes also passed a local nested-field index probe; nested native32 structs
remain unsupported. The string-index-specific, native32 ISA and sxisaexec gates
passed locally; the bootstrap passed true-selfhost and gen3 with this C-emitter
change. Full parity is not established.

Before this indexing increment, fresh local `./sx ci` completed successfully,
including the published-language v1 acceptance chain. This is local evidence
for that earlier source state, not guarded remote CI or acceptance of later
changes. Full guarded CI remains required for R02.

**2026-11-19 local R02 increment: bounded string struct fields**

The i386, AArch64 and RV64IM emitter accepts string literals or existing string
values in untyped struct fields, alongside numeric fields. Fields may be read,
shown, copied or used in `len`/`string_eq`; layouts and recursive frames are
bounded and a field's inferred kind must agree across instances. Assignment to
string fields and computed string initializers remain refused. Seven new
refusals include kind mismatch, wrong operands, unsupported writes/expressions
and the 60-word frame cap; the former string-field refusal now checks numeric
misuse instead. The shared fixture has an independent oracle across seed-min,
gen2, native AOT, full native, IR VM and all three native32 targets. The
20-string-field frame boundary agrees with seed and native32. `test-struct-string`,
the three ISA gates and `test-native-sxdefs` passed locally, including repeatable
images and ARM/RV goldens.

At this checkpoint, gen2 and x86-64 still rejected a string field selector
as another field's initializer. The later increment above addresses that bounded form. Full structs and R02 remain open.

**2026-11-19 local R02 increment: numeric struct field-assignment parity**

The x86-64 native AOT and full native compilers now accept numeric field writes
on bound struct variables, including function-local recursive values and RHS
calls; struct-parameter and nested-target writes remain refused. The existing
`struct_mutation` and new `struct_mutation_scope` independent oracles agree
across seed-min, gen2, native AOT, full native, IR VM, i386, AArch64 and
RV64IM. Six explicit refusal fixtures run on both x86-64 profiles and all
three native32 targets; recursive frame isolation and the native32 64-frame
fault are tested. Deterministic ISA images, i386 sizes and new ARM/RV goldens
are gated. `test-struct-mutation` requires i386 execution instead of silently
skipping it. That gate, the three ISA gates, `test-native-sxdefs`, and
`test-native-sxemit` passed locally. The local `./sx ci` run passed
`true-selfhost`, `gen3` and `native-test`, but failed the final published-language
contract integrity check: seven reviewed-source hashes did not match. The
`tools/native32.sa` pin was already stale in the branch base. The affected
source pins have been refreshed; the later full local CI passed as noted above. The native anchor was
source-rebuilt at an identical compiler2/compiler3 fixed point and its size is
unchanged; this is not an independent trust proof. Full guarded CI and the
remaining struct features are not established by this increment. R02 remains
open.

**2026-11-19 local R02 increment: bounded growing numeric lists**

Empty-origin numeric lists now support runtime length and checked `push`, reads
and writes on i386, AArch64 and RV64IM, with a 16-element cap and exit 1 on
capacity or bounds faults. Tests cover recursion, loop resets, side effects,
reference output, deterministic images and refusals. This is not general dynamic
list support: aliases, list parameters/returns and growth from nonempty literals
remain open. R02 still requires general aggregates, floating-point, file/runtime
APIs, GC, general string expressions and complete guarded CI.

**2026-11-19 local R02 increment: fixed-list element writes**

The three native32 targets now lower checked numeric list element assignment,
including negative/nested indices and function-local recursive frames. List
literal initialization inside a loop runs on each iteration. Independent output
oracles, bounds faults, refusal cases, deterministic images and applicable
seed/gen2/full-native comparisons pass locally alongside the three ISA gates,
`test-sxisaexec` and `test-native-sxdefs`. The native_aot subset refuses list
assignment, the full native compiler faults on negative list indices, and the
C lanes reject some nested-index assignment forms. General dynamic lists and the rest
of R02 remain open; complete guarded CI has not run.


**2026-11-19 local R02 increment: bounded numeric structs**

Numeric struct declarations, field initializers, reads and assignments lower to fixed
words for i386, AArch64 and RV64IM, including recursive function-local values.
The shared fixture agrees with seed-min, gen2, native AOT, the portable IR VM,
and the three native32 targets; an additional seed/native32 fixture covers
forms currently rejected by gen2/native AOT. At that stage, field assignment agreed with the
seed and gen2 but was refused by the x86-64 native compilers; the increment
above resolves the bounded numeric-variable case. Twenty-two new malformed and bound
refusals run per ISA. The ISA gates, `test-sxisaexec` and `test-native-sxdefs`
passed locally. General struct semantics and the rest of R02 remain open;
complete guarded CI has not been run.


**2026-11-19 local R02 increment: runtime indexing of fixed lists**

Fixed numeric lists now support checked runtime index expressions on i386,
AArch64 and RV64IM, including recursive frame-local lists. Negative indices
count from the end as on the C-output lanes; both x86-64 native compilers
currently fault on those indices, an outstanding cross-backend discrepancy.
Same-named lists in different functions are scoped separately, fixing a silent
length miscompile. Unsafe list rebinding/type changes are explicitly refused.
The three ISA gates, `test-sxisaexec`, and `test-native-sxdefs` passed locally,
including independent output oracles and high/low out-of-range faults. This is
not growing-list support, full native parity or guarded complete CI.


**2026-11-19 local R02 increment: list elements containing calls**

The native32 list-element scanner now respects nested parentheses, brackets,
quoted strings and escaped quotes when finding separators. Multi-argument and
nested numeric calls can therefore initialize fixed numeric lists, including
function-local and recursive lists. A hand-calculated oracle, deterministic
ISA images, cross-backend execution, and malformed/arity refusals cover the
change. `./sx target test-native32 test-native-arm64 test-native-riscv64
test-sxisaexec` passed locally; a native-only string-literal separator case is
separate because seed-min rejects that syntax. This is not full native parity
or guarded complete CI: R02 remains open.

**2026-11-17 update: a debugger for the portable IR VM — same interpreter, stop test on**

`tools/sxirexec debug` / `debug-bundle` make the portable IR virtual machine
steppable: breakpoints by the source offset `prog.ir` itself prints or by
instruction index, `step [k]`, `next` (step over a call), `continue`,
`where`/`src`, `bt`, `regs`/`reg <name>`, `mem <addr> [len]`,
`info`/`delete`/`clear`, `help` and `quit`. A session is a command file, or `-`
to read commands from stdin; comments and blank lines are skipped on both paths,
one command is consumed per stop, and a session always stops at the first
instruction because that is where a script sets its breakpoints.

The point is what it is *not*: not a second interpreter. `execute_ir` takes the
script path, and with it empty the interpreter prints nothing and takes no
debugger branch, so the run a gate compares four ways and the run a user steps
through are the same loop. Every stop line leads with the source offset and
then the VM instruction index and call depth, because the listing's `I<n>` label
and the VM's index are different numbering schemes and pretending otherwise
would be the first lie in a debugging session.

It is honest about its limits too: no source line table (the emitter records byte
offsets, not lines), no variable names or types (the portable IR carries no debug
information, so stack slots are what the machine offers), and no conditional
breakpoints, watchpoints, reverse execution or machine-binary debugging. Each of
those is written down in [DEBUGGER.md](DEBUGGER.md) rather than approximated.

Evidence: `./sx target test-ir-exec` pins two sessions byte for byte
(`selfhost/debug_tests/fact.session` and the stdin `stdin.session`), compares the
debugged program's own output with a native build, and requires a missing session
file to fail the run; the pre-existing four 4-way parity cases and five
`native == IR VM` cases still pass unchanged.

**2026-11-17 update: byte regular expressions — a bounded engine, not a guess**

`stdlib/regex.sa` (`rx_*`) answers "does this text contain that shape, and
where" in Sayanox, over bytes: literals, `.`, ASCII classes with ranges and the
`\d`/`\w`/`\s` complements, `\xHH` and control escapes, capturing and `(?:`
groups, alternation, greedy and lazy `*` `+` `?` `{m}` `{m,}` `{m,n}`, and
`^` `$` `\A` `\Z` `\b` `\B`. Matching is a backtracking VM over a flat code
list, and its preference order is Python's: `a|ab` on `"ab"` matches `"a"`, `a*`
is greedy, and fullmatch backtracks until the match covers the subject. `.` is
one byte and never matches LF; `$` also matches before a trailing LF. Because a
Sayanox list holds numbers only, the API returns spans and one group's text at a
time (`rx_find`, `rx_span`, `rx_groups`, `rx_group`, `rx_text`, `rx_match`,
`rx_full`, `rx_search`, `rx_find_all`, `rx_count`, `rx_replace`,
`rx_replace_first`, `rx_escape`) rather than a list of strings.

The interesting part is what it refuses. Backreferences, lookaround, inline
flags, named groups, possessive quantifiers, POSIX classes, unknown letter
escapes, a range whose end is below its start, an unterminated class or group, a
quantifier with nothing to repeat, `{m,n}` with `m > n`, and — the one that
matters most — an **unbounded** repetition whose body can match the empty string
(`(a*)*`, `(a?)+`) all make `rx_valid` answer 0 and every matcher answer -1. A
bounded engine that says "no" is useful; one that silently reinterprets
`[[:alpha:]]` as a class of `[`, `:`, `a`, `l`, `p`, `h` is not, and the first
draft did exactly that until the fuzz corpus caught it. The limits are equally
explicit: 200-byte patterns, 1024-byte subjects, 16 groups, 256 matches per
find-all/replace, and a 250,000-step budget per anchored attempt that reports
exhaustion as -1 instead of hanging on a pathological pattern.

Verification is **288 frozen expectations** in
`selfhost/stdlib_regex_test.sa` / `.want`: 64 acceptance rows, 92 first-match
span-and-capture rows, 20 anchored/full rows, 24 non-overlapping-match and count
rows, 32 replacement rows, 24 escaping rows, and two hand-written contract
sections (20 refusals, 12 limits) because Python accepts forms this engine
refuses. Everything outside the contract sections is computed outside Sayanox
with Python 3.11's own `re` in `re.ASCII` mode. Behind the fixture, the engine
was differentially fuzzed against that oracle on 3,520 generated
pattern/subject rows and 720 replacement rows with zero disagreements — and that
fuzz found four real defects the curated corpus missed: a class after a group
reset the group count to zero, unset groups started at 0 instead of -1, a
`{m,n}` parse error fell back to literal text, and `rx_full` could not
backtrack into a longer alternative. The empty-match rule is Python's post-3.7
one (resume at the same offset with an empty match refused), which is why
`.*?` on `"ab"` yields `(0,0)`, `(0,1)`, `(1,1)`, `(1,2)`, `(2,2)`. The fixture
matches byte for byte on seed-min, gen2 and `native_aot` through
`test-stdlib-next`, and `examples/regex.sa` agrees on seed-min, gen2,
native_aot and the full native compiler. **Not** modelled: Unicode-aware
classes, case-insensitive and multiline modes, lookaround, backreferences,
splitting into a list of strings (that list type does not exist), and streaming
a subject larger than the cap. So R07 stays open.

**2026-11-16 update: word boundaries — UAX #29**

`stdlib/uword.sa` (`uwb_*`) answers where words begin and end, which is the
question a reader's "select word" and a tokenizer both actually ask: `don't` is
three grapheme clusters and one word, `3.14` is four clusters and one number, and
CJK text has no spaces, so only the standard's rules can say where a word ends.
It implements WB1-WB999 of UAX #29 for Unicode 17.0.0 from the Character
Database itself: 1,432 `WordBreakProperty.txt` entries merged into 1,100 class
ranges over 19 classes, plus 451 `emoji/emoji-data.txt` entries merged into 156
`Extended_Pictographic` ranges for WB3c (`ZWJ` x pictograph), all searched by
bisection. WB4 is handled the way the rule is written rather than by rewriting
the text: the engine keeps a previous/next significant index per position, so
`Extend`, `Format` and `ZWJ` are looked past on both sides of a candidate
boundary. The API is the text layer's shape — `uwb_class`/`uwb_is_extpict` for
one code point (-1 for a non-scalar), `uwb_breaks_cp`/`uwb_count_cp` over a code
point list, `uwb_breaks`/`uwb_count` over a string in **byte** offsets, and
`uwb_word_start`/`uwb_word_end`/`uwb_slice`/`uwb_take`/`uwb_drop` for the words
themselves; malformed UTF-8 and text over 4,096 code points give `[]`, -1 and
`""`.

Verification is **all 1,944 cases of the official `WordBreakTest.txt`**, read at
run time, and every case is judged **twice**: once over its code points and, when
it does not contain U+0000 (a string cannot carry a zero byte), once over a
string built from them, where the expected byte offsets are the official
code-point offsets mapped through UTF-8 lengths rather than through the module's
own offset helper. The same fixture then cross-checks the generated tables
element by element against `WordBreakProperty.txt` and `emoji-data.txt` (sorted,
merged and compared, so a missing, extra or mis-classed range fails even where no
test case reaches it) and sweeps both lookups at every 257th scalar — 4,328
points. The 67-line depth oracle matches on seed-min, gen2 and the full native
compiler, and a 27-expectation compact companion carrying one verbatim official
case per rule matches on **all four backends** including the bounded
`native_aot`.

Two rule bugs were found by the oracle and are worth recording. WB3 (`CR` x `LF`)
has to win over WB3a/WB3b, so the "nothing joins to a newline" test must run
first and be overridden, not the other way round. WB13a/WB13b include
`ExtendNumLet` on *both* sides, so `a__b` is one word — leaving it out of the left
set split a run of underscores. Two backend facts were also forced by this
module: `native_aot` has no list element assignment, so the three scratch lists
are built with `push` alone (and the backwards pass is reversed by a second
pass), and `/` is float division, so every integer division goes through
`u8_div`. **Not** modelled: sentence boundaries (the SB rules of the same UAX),
line breaking (UAX #14), locale tailoring and collation. Bidi and collation stay
open, so R07 stays open.

**2026-11-16 update: identifier syntax — UAX #31 XID properties**

`stdlib/uident.sa` adds the Unicode identifier properties a lexer, linter or
rename tool needs, so a name can be checked against the standard instead of
against ASCII. `uid_xid_start` and `uid_xid_continue` answer one code point from
the 779 `XID_Start` and 1,422 `XID_Continue` ranges of Unicode 17.0.0
`DerivedCoreProperties.txt`; `uid_valid` answers a whole string and
`uid_valid_list` a code point list. Verification sweeps **all 1,114,112 code
points** (surrogates included, where the contract is -1) twice — once per
property — against run-length output frozen from an independent Python
reference, and the 3,058-line depth fixture plus its 34-expectation compact
companion run on **all four backends** from one oracle. U+005F is the case worth
naming: LOW LINE is `XID_Continue` but not `XID_Start`, yet every language using
these properties lets an identifier *begin* with an underscore, so `uid_valid`
accepts exactly one leading U+005F and nothing else outside the properties; the
compact companion pins `start _ 0` next to `continue _ 1`. Two readings of
"valid" are kept apart on purpose: UAX #31 asks an identifier to be in NFKC, but
CPython's `str.isidentifier` does not enforce it (it answers `True` for
`e` + U+0301 while rejecting the ZWJ join the newer UCD allows), so `uid_valid`
is the Python-agreeing, property-only answer and `uid_valid_nfkc` is the stricter
one a compiler canonicalising tokens wants. Getting this wrong in the other
direction first — the header claimed CPython enforced NFKC — is worth recording
because the sweep is what disproved it. The failure contract is the text layer's:
-1 for a non-scalar, malformed UTF-8 or input over the shared 64 KiB cap, 0 for
well formed but not an identifier. **Not** modelled: identifier equivalence
(`uid_valid_nfkc` plus case folding), the Pattern_Syntax/Pattern_White_Space
profiles as separate APIs, and any script restriction. Bidi, collation and real
sockets stay open, so R07 stays open.

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
Bidi and collation stay open, and so do real sockets (NFKC/NFKD and streaming CSV landed 2026-11-16), so R07 stays open.

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
