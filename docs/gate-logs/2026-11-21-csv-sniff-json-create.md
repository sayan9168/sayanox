# CSV dialect sniffing and JSON path creation — 2026-11-21

Branch `arena/875f0c9e-sayanox`, based on `main` at `0edaafb`. This is the
stdlib half of the day's work: two operations that a data pipeline needs and this
standard library did not have — recognising a delimiter you were not told, and
creating JSON structure instead of only editing the structure that is already
there. Both land with a frozen, independently computed oracle and run on four
backends.

## What landed

| Module | New surface | Contract |
|---|---|---|
| `stdlib/csv.sa` | `csv_sep_count`, `csv_line_cut`, `csv_first_line`, `csv_sniff_lines`, `csv_sniff_list`, `csv_sniff`, `csv_parse_row_sniff` | the delimiter byte a sample was written with, `-1`/`""` when it cannot be said |
| `stdlib/json_deep.sa` | `jd_replace_at`, `jd_new_container`, `jd_build_tail`, `jd_check_path`, `jd_append_child`, `jd_put_raw` | set a value at a dotted path, creating the containers that are missing; `""` for every refusal |

### The sniffing rule

Statistical dialect detection (the `csv.Sniffer` shape) reports a *guess*. A
guess in a library is hard to test and harder to debug, so `csv_sniff` is a
mechanical rule over a bounded sample:

1. split the sample at LF, drop a trailing CR, ignore empty lines, and look at at
   most the first **4096 bytes** and the first **64 non-empty lines**;
2. a candidate delimiter `d` matches when **every** line holds the same number of
   unquoted `d` bytes, that number is at least one, and every line also parses as
   a valid row under `csv_is_valid_row_d(line, d)`;
3. a byte is unquoted when it sits outside a field that *begins* with `chr(34)`,
   with a doubled quote read as an escaped quote;
4. the winner is the matching candidate with the most unquoted separators in the
   first line; a tie keeps the earlier candidate.

`csv_sniff` tries comma (44), TAB (9), semicolon (59) and pipe (124) — exactly
the set `csv_delim_ok` accepts, so a sniffer can never hand its caller a
delimiter the parser would refuse. `csv_sniff_list(sample, cands)` takes the
caller's own candidates and its own tie order, and skips an illegal candidate
instead of guessing around it. `csv_parse_row_sniff(line, sample)` is the
one-step form: `""` when the dialect is unknown, so `-1` is never passed to
`csv_parse_row_d`.

Two refusals are the point of the design rather than accidents:

* **one column is not a comma file.** A sample whose lines carry no separator
  explains every dialect equally well, so it returns `-1`; defaulting to comma
  there is how a semicolon export silently becomes one giant field.
* **a row that quotes in the middle is a bad sample.** `gadget,"two<TAB>tabs"` in
  a TSV file has a `"` inside an unquoted field, which this codec refuses (one of
  its three malformed-row refusals), and a refused line kills the candidate.
  Underlying that, `csv_parse_row_d` requires the byte after a closing quote to be
  the delimiter, so a comma-separated row cannot be read as TAB-separated at all.

### The creation rule

`jd_set_raw` can only replace a value that exists, so building a document meant
hand-writing JSON text. `jd_put_raw(doc, path, raw_val)` walks the path and
creates what is missing, with one rule that keeps a dotted path unambiguous: a
segment made only of decimal digits indexes an **array**, any other segment is the
key of an **object** member. A missing array gets exactly one element, index `0`
— index `3` in an empty array would need three invented slots, so sparse creation
is refused instead of padded. Appending to an *existing* array at its length is
allowed, past the length is not. Existing members are replaced whole; a scalar is
never retyped into a container. Both inputs must be complete valid JSON. An empty
path is the one documented non-refusal: it replaces the whole document, through
`jd_set_raw`.

Every byte the operation does not touch survives, which is what makes the result
safe to write back over a file: `{ "a" : [1e2, 2], "b" : 1.50 }` grows a member
and still contains `1e2`, `1.50`, and the author's spacing.

## Oracles

Nothing is pinned from the implementation's own output. Both fixtures were
written by a host-side generator that computes each expected value **twice, by
independent routes**, and refuses to emit a `.want` when the two disagree:

* `selfhost/stdlib_json_put_test.sa` (112 pinned rows) — route one parses the
  document with Python's `json` module (with the same first-duplicate-key rule and
  identity number hooks the Sayanox reader uses), edits the model, and
  re-serialises it; route two splices the value's bytes into the original
  document text, member by member, using its own scanner. A row is accepted only
  when the hand-written expectation, the parsed model and the byte splice all
  agree. On top of that, each accepted result is re-read through the *existing*
  reader (`jd_valid`, `jd_type`, `jd_text`, `jd_num`, `jd_len`, `jd_flag`), so the
  creation block is checked against a reader it does not share code with, and each
  result carries a `len()` guard so a truncated value cannot pass unnoticed.
* `selfhost/stdlib_csv_sniff_test.sa` (106 pinned rows) — every sniffing row is
  additionally cross-checked against Python's own `csv` module over the same
  bytes. Seven rows deliberately diverge, all of them `x,"y` or `a"b,c` forms: an
  unterminated or misplaced quote, which this codec refuses and Python's
  `QUOTE_MINIMAL` reader absorbs. Those seven are written into the fixture as
  refusals rather than reconciled.

## What writing them caught

* `csv_line_cut` indexed `sample[b - 1]` without clamping `b` to the sample, and
  `csv_sniff_lines` scanned past `len(sample)` when the caller's bound was
  longer than the text — both `sx: string index out of range`. The bound is now
  clamped in the callee *and* at the call site.
* `csv_sniff_lines` kept counting rows after a line that failed to parse, so an
  invalid sample could still return a positive count. It now returns `-1` as soon
  as `bad` is set.
* Two loops were written `while a < n && ok == 1`, which `native_aot` refuses
  outright (`unexpected text in while condition`); they became a mutable `stop`
  plus a flag loop, which every backend accepts and which is what the rest of the
  stdlib already does.
* The first draft of the generator compared a hand-written JSON string against
  `json.loads` defaults and "failed" on every number, because the module keeps
  number text as text; the oracle loader had to grow the same
  `parse_int`/`parse_float` identity hooks as the model it was checking. It also
  mis-read a legitimate scalar root replacement as a refusal until results were
  wrapped in a `{"__result__": ...}` envelope.
* The first `.want` mismatch turned out to be a *generator* bug — its
  `case(expr, name, *args)` helper passed the outer `len(...)` arguments to the
  inner call, so `show len("a,b\r\nc,d", 0, 0)` was emitted. Fixture statements
  are now rendered from an explicit value table, and a per-statement realignment
  tool compares each `show` with its own slice of the run (line-diffing a
  multi-line value is how a whole session gets lost).

## Backend constraints recorded for the next fixture

* gen2 (and seed-min) reject `}` inside a single-line `give` expression
  (`a '}' ended up inside a give expression; put one statement per line`) — this
  includes `when c { give f("x") }` — while the full compiler that builds
  `tools/sxgates` accepts it. `tools/*_gates_lib.sa` is compiled by the full
  native compiler, so gate code may use the shorter form; `stdlib/*.sa` and the
  `selfhost/` fixtures may not.
* A `make` body must put one statement per line whenever a string literal carries
  an escape.
* a `use` path resolves from the directory of the main program, not the working
  directory, so a probe that reads a project's `.sayanox/registry` has to be
  *written* inside that project for the splice to be found (checked by compiling
  the same probe from both the parent and the program's own directory).

## Acceptance

`ep_next()` was split so the new surface has its own unit, `ep_sniff_create()`,
called from the middle of the gate. That is what makes the two blocks testable
without sitting through every other stdlib family:

```
cp tools/sxparity_gates_lib.sa /tmp/parity.refactored     # working copy
# ep_next() temporarily reduced to: hold focus = ep_sniff_create(); give 0
./sx tool sxbuild /tmp/sx.focus
/tmp/sx.focus target test-stdlib-next
  [OK] sxbuild target: test-stdlib-next
```

which compiled and ran both fixtures on all four backends (8 programs, artifacts
`selfhost/seed_tests/stdlib_next/{csv_sniff,json_put}_{0,1,2,3}`) and compared
each output with the frozen oracle and with the seed-min run. The `ep_sniff_create`
call now sits at the same point in `ep_next()` as the focused run, so the full
`test-stdlib-next` chain executes exactly these bytes.

Negative controls, each run against the frozen oracles and then reverted:

| Control | Change | Gate result |
| --- | --- | --- |
| tie order | `seps > best_seps` became `seps >= best_seps` in `csv_sniff_list` | `[FAIL] CSV dialect sniffing independent oracle` |
| one-column samples | the `want < 1` refusal removed from `csv_sniff_lines` | `[FAIL] CSV dialect sniffing independent oracle` |
| path validation | `jd_check_path` made to `give 1` before any check | **passed** |

The third row is a real gap and is recorded as one, not smoothed over: no pinned
JSON row currently depends on `jd_check_path`, so the helper is defense in depth
against a path segment that cannot be spelled as a JSON string key, and it is not
yet an *oracle-pinned* rule. Widening the fixture with a segment the check alone
rejects is open work (R07), and so are the remaining per-refusal controls
(padded index, name into an array, scalar in the way, index past the end), which
were not run in this increment. The two CSV controls above and this one are the
whole control set for now; nothing here claims more than that.

Backends for both fixtures, run directly as well as through the gate:

| Backend | `stdlib_csv_sniff.want` | `stdlib_json_put.want` |
| --- | --- | --- |
| `selfhost/seed/sxc_seed_min` (kind 0) | byte-exact, 108 lines | byte-exact, 114 lines |
| `selfhost/gen2` (kind 1) | byte-exact | byte-exact |
| `selfhost/native_aot` (kind 2) | byte-exact | byte-exact |
| `selfhost/gen1_min` (kind 3) | byte-exact | byte-exact |

Pins: `tools/sxparity_gates_lib.sa`, `tools/sxpkg_gates_lib.sa` and
`docs/REMAINING_WORK.md` were re-pinned in `docs/full-language-v1.sha256`, and
`docs/full-language-v1.sha256`, `tools/sxparity_gates_lib.sa` and the rebuilt `sx`
driver in `bootstrap/sx.sha256` (the driver embeds the gate, so it is rebuilt
from source and installed, not edited). `sha256sum -c` passes for both manifests
and `./tools/sxfull verify` reports
`[OK] published-language v1: complete clause and builtin inventory, source/case pins`.
`stdlib/*` and the new `selfhost/` fixtures are not manifest-pinned, which is why
they needed no entry.

`examples/csv_sniff.sa` and `examples/json_create.sa` are runnable tours of the
two APIs; each was compiled by seed-min, gen2 and `native_aot` and the three
outputs are byte-identical.

This is local gated acceptance for one stdlib increment. It does not close R07,
does not establish independent bootstrap trust, and does not claim the IR VM,
i386 or AArch64/RV64 execution of these two fixtures: `test-stdlib-next` covers
the four C/native backends listed above, and the cross-ISA oracle families that
cover them are separate gates.
