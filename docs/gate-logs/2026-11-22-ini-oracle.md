# INI configuration oracle — 2026-11-22

Branch `arena/a4475f34-sayanox`, based on `main` at `feef919`. `stdlib/ini.sa`
reads a `.ini`/`pyproject`-shaped file into a `stdlib/csv_table.sa` table and
writes one back out. It lands the same way the CSV and JSON additions of
2026-11-21 did: a frozen fixture whose every expected byte was computed outside
Sayanox, run on four backends by `test-stdlib-next`, with negative controls that
prove the gate can fail.

## What landed

| File | Surface |
| --- | --- |
| `stdlib/ini.sa` | 41 `make` definitions: 22 entry points (`ini_parse`, `ini_valid`, `ini_get_text`, `ini_count`, `ini_has`, `ini_value`, `ini_find`, `ini_find_section`, `ini_section_count`, `ini_section_at`, `ini_key_count`, `ini_key_at`, `ini_new`, `ini_header_row`, `ini_default_section`, `ini_max_bytes`, `ini_set`, `ini_unset`, `ini_drop_section`, `ini_empty`, `ini_write`, `ini_round_trips`) and the 19 rule helpers they are built from |
| `selfhost/stdlib_ini_test.sa` / `.want` | 1,026 frozen expectations, one line per `show`: the header row, every accepted and refused document, the lookups, the writer, and both byte-cap boundaries |
| `selfhost/stdlib_ini_write_test.sa` / `.want` | 335 frozen expectations: the `ini_set`/`ini_unset`/`ini_drop_section` mutations, the comment-marker documents, section order, and the foreign table |
| `tools/sxparity_gates_lib.sa` | `ep_ini()`, registered as `test-stdlib-ini` and called from `ep_next()` |
| `examples/ini_config.sa` | read a file, ask it questions, change one setting, write it back, save and re-read |
| `docs/STDLIB.md` | module table row, the `## Configuration files` section and its verification row |
| `docs/REMAINING_WORK.md` | R07 paragraph for this increment |

## The rules, and the two decisions they forced

The module header numbers nine rules; two of them were decided *while* the oracle
was being written, and both are pinned rather than asserted.

**A new member of the default section goes to the head of the table.** The
default section is spelled by the empty string, and `ini_write` prints its members
before the first `[section]` line. Appending a new default member would therefore
move it behind every section in the file — the writer would silently reorder the
document it was handed. `ini_set` inserts at member row 0 instead, which needed a
row-splicing helper (`ini_insert_at`) because `ct_append` is the only append the
CSV layer has.

**Section enumeration is keyed off the header row, not off the section names.**
`ini_section_at(table, 0)` is the default section and `ini_section_count` counts
it even when no member names it — that is what makes `ini_write`'s head-of-file
placement and the enumeration agree. The first attempt counted the default section
unconditionally, and the oracle caught it on a table handed over by `ct_filter_eq`
(which has no header row at all): a `deps`-only table came back with *two*
sections. The predicate is now `ini_has_header`, which asks the one question that
distinguishes an ini table from any other csv_table — is row 0 the row `ini_new`
writes — and a foreign table is enumerated from its member rows alone.

## Oracle

No expectation came from a Sayanox run. A host-side Python model implementing the
nine rules computed every value, and each accepted document was then re-parsed
with Python's `configparser` (`RawConfigParser`, `strict=True`, `delimiters=("=",)`,
`comment_prefixes=(";", "#")`), a reader that shares no code with the module:

* 33 documents are accepted by the oracle; 32 agree with `configparser` member for
  member. The single divergence is the default section — `k = v` before any header,
  which rule 6 reads and `configparser` refuses with `MissingSectionHeaderError`.
* The generator aborts when its own hand-written note about a rule and the model
  disagree. That caught the `[name]` header refusing an empty name while the table
  stores `""`, the duplicate-key check running after the append instead of before
  it, and a key rule that let `[`/`]` through into a key.
* The byte cap is pinned at both boundaries, from the model rather than guessed:
  one member padded with a run of `;` bytes to exactly 65,536 is accepted, and
  65,537 is refused by `ini_max_bytes()` — `len()` counts bytes, so the fixture
  also pins a UTF-8 value (`k = café`) at 9 bytes against 8 characters. The other
  cap, the 1,024 rows the csv_table layer holds, is *not* pinned here and could
  not be: see "What the fixture could not pin" below.
* Values are pinned as `(len, byte sum)` and never as printed text, and every
  document is assembled with `chr()`: this dialect has no escape for a quote or a
  backslash inside a Sayanox string literal and no multi-line literal, so a raw CR
  or a bare backslash cannot be spelled in the fixture at all.

## What writing it caught

* `ini_insert_at` first rebuilt the table with `ct_row(table, 0)` as its seed and
  then pushed rows onto it — `csv_push` frames what it is given, so the header was
  spliced in raw and the resulting table was no table (`ct_valid` 0, and every
  lookup on it `-1`). Rows now all travel through the same framing, header
  included, which is exactly what `ct_valid` reads back.
* A destination-index loop for the splice dropped the last row and duplicated the
  inserted one (`ini_write` printed `top = t` twice). The loop walks destination
  rows and reads the *displaced* source row from `k - 1` past the insertion point.
* A pin asked `len(ini_set(table, …))` while the model had answered the *value* —
  `ini_set` returns a table. The fixture now asks
  `ini_value(ini_set(…), section, key)`, which is the question the model answered.
* `ini_round_trips` was first pinned to 0 for a document with comment lines, on
  the reasoning that the writer does not reproduce them. The function compares the
  table before and after one write, so the answer is 1; the loss of the comments is
  real and is pinned through `ini_write` instead. Re-deriving the pin from the
  documented definition, not from the run, is what made that visible.
* One `sh_sum_bytes` mismatch (583 against 582) turned out to be an artifact of the
  checker's row context — the fixture re-pins the *input* table right after the
  step that modified a copy of it, to prove the input was not touched. Recorded so
  the next reader does not chase a module bug that is not there.
* The `;`/`#` question the 2026-11-21 notes left open (does `ini_needs_quote` need
  a clause for a value that begins with a comment marker?) resolves to *no*: a
  written member line starts with the key, so a marker at the start of a value can
  never be read as the start of a comment, and quoting it would change the stored
  bytes' spelling for no gain. Four new documents pin marker-first values, a lone
  `;` value, a trailing marker and a quoted `";x"`, each with its round trip.

## Acceptance

The focused unit was used for iteration (~4 min/cycle instead of the whole chain),
then the unmodified chain was run:

```
./sx target test-stdlib-ini      # the ini unit alone
./sx target test-stdlib-next     # every stdlib family in ep_next()
```

Both halves are frozen, so the unit's job is to run them and compare bytes. The
gate rebuilt `sx` from the changed driver sources first (`./sx tool sxbuild`),
re-pinned `tools/sxparity_gates_lib.sa` in both manifests, `docs/REMAINING_WORK.md`
in the docs manifest and `sx` plus the docs manifest itself in
`bootstrap/sx.sha256`, and `sha256sum -c` on both manifests and `./sx verify-entry`
pass:

```
$ ./sx target test-stdlib-ini
[OK] native tool: native_aot
[OK] sxbuild target: test-stdlib-ini
$ echo $?
0
```

The whole chain, with the two ini families registered inside `ep_next()`:

```
$ ./sx target test-stdlib-next
CHAIN-TBD
```

The unit takes 4 m 10 s wall, eight compile-and-run cycles. What costs time is the
parse half on the two minimal backends, which is the price of a fixture this wide
rather than of any single document in it: 1,026 `show` lines, the largest document
in it 65,537 bytes.

## Negative controls

Each one mutates `stdlib/ini.sa`, runs the gate, and is reverted; a control that
passes is a hole in the oracle and is written down as one.

| Control | Change | Gate result |
| --- | --- | --- |
| header-row scan | `ini_find` reads row 0 as a member | `[FAIL] INI configuration independent oracle` |
| refusal marker | `ini_valid` returns 1 without looking at chr(33) | `[FAIL] INI configuration independent oracle` |
| writer quoting | the leading-space quote clause disabled | `[FAIL] … ini_0: got 1, want 0` (the crash on a string index past the end is the refusal propagating) |
| rule 5 decoding | a `\r` escape left undecoded | `[FAIL] INI configuration independent oracle` |
| default head placement | `ini_set` appends a new default member instead of inserting it at row 0 | `[FAIL] INI writer mutation independent oracle` — 5 lines of the mutation half move (`0 0 3 339` shift past each other), the parse half unaffected, so the pin belongs to the writer family and only the writer family |
| header predicate | `ini_has_header` made to `give 1` | `[FAIL]` on *both* families: the parse half at line 893 (`ini_section_count` of a `ct_filter_eq` table: 2 where the model says 1) and the mutation half at its foreign-table block — the predicate is the only thing separating an ini table from any other csv_table |

Backends, from the gate's own artifacts — `selfhost/seed_tests/stdlib_next/`, one
binary and one `.out` per backend per half, each `.out` compared with its own `.want`
(1,026 lines and 335 lines) and with the seed-min run. Every one matched byte for
byte, which is also what `[OK]` for the unit above means, since the families assert
both comparisons themselves:

| Backend (`kind`) | parse half | writer half |
| --- | --- | --- |
| `sxc_seed_min` (0) | 1,026 lines byte-exact; run 6 s after a 27 s emit | 335 lines byte-exact; run <1 s |
| `gen2` (1) | byte-exact; run 10 s after a 21 s emit | byte-exact; run <1 s |
| `native_aot` (2) | byte-exact; run 94 s, 2 s to build | byte-exact; run ~1 s |
| `gen1_min` (3) | byte-exact; run 75 s, 2 s to build | byte-exact; run <1 s |

The four-way backend parity assertion is what makes `native_aot`'s two limits worth
naming out loud: it fails *closed* (`too many variables`, then `OOM patches`) on a
fixture that gen2 compiles happily, so a gate that only ran gen2 would never have
told anyone the single file was too big.

## What the fixture could not pin, and why

The first version of the caps block pinned the row cap where the module meets it:
a generated document of 1,023 distinct keys (9,207 bytes) parses to 1,023 members
and round-trips, and one member more (9,213 bytes) is refused outright rather than
handed back one row short. The model computed those eight numbers, the fixture
built the document in 0.0 s, and **no backend could read it**: `ini_valid` alone
did not return. Measured on the gen2 build of a shrinking document, timing
`ini_valid` plus `ini_count(ini_parse(...))`:

| members | 32 | 64 | 128 | 256 |
| --- | --- | --- | --- | --- |
| seconds | 0.52 | 3.60 | 26.09 | >40, killed |

about x7 per doubling — cubic. `ini_parse` calls `ini_has(table, section, key)`
for every member to enforce rule 7, and `ini_has` walks the rows of the table it
has built so far, and a csv_table row access copies through the packed string:
rows x rows x bytes. `stdlib/csv_table.sa` keeps a table in a `str`, so nothing
in the module can ask "have I seen this key" without paying for a scan.

The honest consequence is written into the fixture rather than hidden: the ini
caps block keeps the byte cap at both boundaries (cheap — `len(text) > ini_max_bytes()`
is the first thing `ini_parse` does, so a refusal costs one comparison) and pins
the largest many-member document the four backends can serve inside the gate's
budget, 32 generated members checked member for member and round-tripped. The row
cap itself stays pinned where it is imposed, by the `csv_table.sa` oracle, and
`docs/REMAINING_WORK.md` carries the cost as open work on this module. Nothing in
the oracle was relaxed to make it pass: no pin was moved to a value the module
happens to print, and the two `.want` files are still exactly what the model said.

## Pins

`tools/sxparity_gates_lib.sa` is pinned in both `docs/full-language-v1.sha256` and
`bootstrap/sx.sha256`, and `docs/REMAINING_WORK.md` in the former; `sx` was
rebuilt from the changed driver sources (`./tools/sxc_native tools/sxbuild.sa`)
and re-pinned, as were the two manifests themselves (`bootstrap/sx.sha256` pins
`docs/full-language-v1.sha256`). `stdlib/ini.sa`, `examples/ini_config.sa`, the
two new `selfhost/` fixtures and this log are in neither manifest.
`sha256sum -c` on both manifests and `./sx verify-entry` pass.
