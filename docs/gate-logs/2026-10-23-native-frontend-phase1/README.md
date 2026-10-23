# The native backend's front end starts leaving C (2026-10-23)

`docs/ALL_SAYANOX_PHASE.md` has carried the same sentence through three
steps of Phase D: *"the scanner, the parser, the type inference, the emit
tree, the runtime stubs and the collector are still C."* `tools/sxlink.sa`
(step 3) and `tools/sxencode.sa` (step 4) are **replays** — one is handed a
code blob and resolved patch records, the other a list of encoder calls — so
neither of them reads a Sayanox program.

**Step 5 does.** `tools/sxdefs.sa` (1,118 lines, 29 functions, built by gen2
and `cc` like every other tool) is `selfhost/native_aot.c`'s phase 1:

* `expand_use()` — the `use` splice, depth at most 8, each path tried
  against the **top** file's directory first and then as written, comments
  left alone, and the newline that ended the `use` line preserved;
* `collect_defs()` — the top-level walk, with the same string-aware
  statement skipping, that builds the four tables every later pass reads:
  concrete structs and their field names, generic struct **templates**
  (which deliberately take no `S[]` slot), functions with their parameter
  names, typed-signature kinds, type parameters and return kind, and the
  globals a top-level `hold` declares with the kind and struct identity of
  its annotation.

| Claim | Where it is checked |
|---|---|
| The expanded source is byte-identical to C's | `make test-native-sxdefs` — `cmp` of `expand.sa` against `tools/sxdefs <file> expand` on nine fixtures |
| The four tables are byte-identical to C's | the same gate — `cmp` of `defs.txt` against `tools/sxdefs <file> defs` |
| The seam changes nothing | each fixture is compiled with and without `SX_DEFS_DUMP`; stdout, stderr and the image must match |
| A program phase 1 refuses is refused **with the same words** | 34 fixtures in `selfhost/sxdefs_tests/refuse/` (33 distinct messages): same text after the tool name, same exit status |
| …including the real compiler | `selfhost/compiler_min.sa`, 20,106 lines, refused by both at `make sxfenv: at most 6 params` |
| The table's shape, so a change on **both** sides still fails | content pins: the two-level splice reaching the function table, both generic templates, a generic signature's per-parameter type indices, `str`/`list`/struct annotations, every field kind still `-1`, exactly six globals, no block-local name |
| The fixture is a real program, not a parse exercise | `program.sa` is compiled by `native_aot` and its 13 lines of output are compared with the tracked `program.want` |

## The seam

`SX_DEFS_DUMP=<dir>` writes `expand.sa` and `defs.txt` **between
`collect_defs()` and `infer()`**, and changes nothing else. The dump point
is the contract: phase 1 deliberately leaves the field kinds, the
unannotated global kinds and every generic instantiation unset, so each
`kind=-1` in the dump is phase 1 saying "not my job", and the comparison
tests one pass instead of two. The gate asserts it, too — if any
`  field ` line ever arrives with a kind, it fails with *"the dump point
moved"* rather than as an unexplained `cmp` diff.

```
; native_aot phase 1
structs 2
struct 0 Point nf=2
  field 0 x kind=-1 sid=-1
...
fn 5 pick nparam=2 gen=1 ntp=2 rk=0 rtp=0
  param 0 a k=0 tp=0
  param 1 b k=0 tp=1
  ftparam 0 T
  ftparam 1 U
globals 6
glob 2 here kind=3 sid=0
```

## Evidence beyond the gate

The gate pins nine fixtures so it stays fast. The port was accepted on a
wider sweep, run by hand on the same binaries after the four gates:

```
151 tracked .sa files (selfhost, stdlib, tools, examples, samples,
                       registry, sayascrape)
145 phase-1 clean  -> expand.sa AND defs.txt byte-identical  (4,221 table lines)
  6 refused by C   -> identical first line, identical exit status
  0 differences
```

The six refusals include `selfhost/compiler_min.sa` and `tools/sxpkg.sa` —
two of the largest Sayanox programs in the tree — so the comparison covers
inputs far past the fixture set.

## The gate was checked against a wrong implementation

Three mutations of `tools/sxdefs.sa`, each reverted immediately:

| Mutation | Result |
|---|---|
| drop the newline C appends after a splice | `[FAIL] the Sayanox use-expansion is not byte-identical for program` |
| rename one table field (` nf=` → ` nfields=`) | `[FAIL] the Sayanox definition tables are not byte-identical for program` |
| one wrong word in a diagnostic (`declared` → `defined` twice) | `[FAIL] different diagnostic for fn_twice`, with both texts printed |

## Two findings worth keeping

**A port must reproduce the quirks or it is a different program.**
`native_aot`'s `skip_stmt()` is string-aware but not comment-aware, so a `{`
inside a comment inside a struct body makes it leave the block late.
`selfhost/sxdefs_tests/quirks.sa` is that program: it is never run (type
inference refuses it), it is *compared*, and both implementations mis-skip
identically. The same file pins that a `use` inside a comment is not a use,
and that `hold here` twice is one global.

**A nested `use` resolves against the top file's directory**, not against
the file it is written in — `mods/geom.sa` has to write
`use "mods/text.sa"`. That is C's behaviour (`expand_use` passes `dir`
unchanged down the recursion); it is now written down in the fixture, in the
tool's header and in `ALL_SAYANOX_PHASE.md` instead of being discovered
again.

## What this does not claim

* `native_aot` still runs its own phase 1 to compile anything. `sxdefs` is
  proved equal to it on fixtures; it is **not** wired in as the producer,
  for the same reason `sxlink` and `sxencode` are not — that changes the
  bootstrap ordering and is its own step.
* Kind inference, the emit tree, the 856-line runtime and the collector are
  still C. `selfhost/native_aot.c` went from 4,498 to **4,597** lines
  because of the seam: this step makes the C file bigger, not smaller, and
  the inventory row in `ALL_SAYANOX_PHASE.md` keeps its line count.
* `make all-sayanox` still exits 1, and Phase E's option 1 (a prebuilt
  bootstrap binary rebuilt from `.sa`) still needs the rest of Phase D.
* `tools/sxdefs.sa` reads with `read_file()`, which stops at a NUL byte, and
  reports a `use` path that names a directory as "cannot open use file"
  where C's `access(R_OK)` lets it through to a read error. Both differences
  are in the tool's header comment.

One number in `hard-gates.log` is stale and was corrected afterwards: the
gate's own `[OK]` line said *"the 19,577-line compiler"*, a count from
2026-10-20 that this week's compiler changes moved to 20,106. The log is kept
verbatim — it is what the run printed — and the Makefile text was corrected in
the same commit. The number is cosmetic; what the check compares is the two
implementations' diagnostics.

Full run: [`hard-gates.log`](hard-gates.log).
