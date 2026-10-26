# 2026-10-26 — CI/CD repair, gated workflows, and a CSV stdlib module

## What was red on `main`

Six consecutive runs were red. The logs (read through the Actions job-log API)
name three different root causes, two of which had already been fixed on the
branch by the time this change was made:

| Run | Where | Root cause |
|---|---|---|
| `40267460446` (main push, `a33bc64`) | `make native-test` / `test-sxbuild` | `sxbuild inventory` reported a non-zero count of non-anchor `.c/.h` files. The `gate-binaries` artifact (`gen2.c`, `gen1_min.c`) was downloaded **inside the checkout**, and the inventory walks the workspace. This was the live failure. |
| `40213409640` (PR #36, `d529891`) | `make native-test` / `test-sxbuild` | same cause. |
| `40177424982` (nightly, `0ad22ed`) | `make true-selfhost` | `No rule to make target 'selfhost/seed/sxc_seed', needed by 'test-seed-gc'`. Fixed by `d529891` (`$(SEED_BIN)` → `seed-bin`). |
| `40077622994` (nightly, `04e6ca6`) | `make native-test` / `test-sxmod` | `cc rejected gen2's flat splice for an unrelated reason`. Fixed by the later module-namespacing work; the current head passes this gate. |
| `40165341354`, `40163595803` | `make native-test` | the same `test-sxbuild` inventory problem. |
| `39989833109` (PR #34) | `make native-test` | earlier instance of the sequential-chain breakage. |

The last green runs before the streak were `39926946230` (nightly) and
`39744905814` (PR) on `9474418`.

## Fixes

1. **Hand-off outside the checkout.** Both `fixed-point` and `native` jobs in
   `.github/workflows/ci.yml` now download `gate-binaries` into
   `${{ runner.temp }}/gate-binaries`, and both restore steps read from
   `$RUNNER_TEMP/gate-binaries`, assert `test ! -e gate-binaries`, and remove
   the temporary directory. The upload step still stages flat files from the
   workspace, which is harmless because that job never runs an inventory gate.
2. **Defence in depth in the tool.** `tools/sxbuild.sa`'s `walk_counts` skips
   transient hand-off directories (`gate-binaries`, `ci-artifacts`) in
   addition to `seed_tests` / `gen2_tests`. A stray copy can no longer turn
   the C-free inventory into a false alarm; an ordinary directory containing
   C is still counted, so the gate is not weakened globally.
3. **The CI shape is a make gate.** `make test-ci-shape` statically checks all
   three workflow files: exactly two `runner.temp` downloads, six
   `RUNNER_TEMP/gate-binaries` references, two `test ! -e gate-binaries`
   assertions, one workspace-relative upload path, both sequential workflows
   running `doctor -> true-selfhost -> gen3 -> native-test` in order, and the
   release workflow's `contents: write`. It runs in the fast `audit` job, in
   the nightly job, in the release job, and as a prerequisite of
   `native-test`.
4. **Nightly audit aligned.** `full-bootstrap.yml` now checks the same six
   extra generated tool binaries as `ci.yml` and runs `test-ci-shape` before
   the 30-minute gates.
5. **CD.** `.github/workflows/release.yml` runs the same four gates in one
   clean job on `v*` tags (or manual dispatch), verifies `gen3.c == gen4.c`
   and the single tracked C/H file, then publishes a source tarball, the
   generated `gen3.c`/`gen4.c`, SHA-256 digests and a `BUILD_INFO.md` as a
   GitHub release. `--verify-tag` is applied only to real tag pushes.
6. **Developer entry points.** `make ci` runs the nightly chain locally;
   README carries CI/full-bootstrap badges and a CI/CD section.

## New feature: `stdlib/csv.sa`

An RFC 4180-style **row** codec for byte strings. The dialect refuses
string-valued list elements, so a parsed row is a packed string
(`<len>:<bytes>` per field), the same representation `stdlib/cli.sa` uses for
argv. `csv_parse_row` validates and parses quoted fields (embedded commas,
CR/LF, doubled quote characters), `csv_write_row` quotes and escapes, and
`csv_ok` / `csv_count` / `csv_at` / `csv_push` / `csv_empty` /
`csv_needs_quote` / `csv_quote` / `csv_is_valid_row` are the public API.
Three malformed rows are refused rather than misread. Gate:
`make test-stdlib-csv` — 44 hand-computed values from
`selfhost/stdlib_csv_test.sa`, identical on seed-min, gen2 and native_aot,
plus standalone-module and prefix-coexistence checks.

## Local verification (this workspace, 2026-10-26 05:00–05:30 UTC)

A single clean sequential run of the nightly chain on a checkout with no
`gate-binaries` directory:

```
make doctor && make true-selfhost && make gen3 && make native-test
```

* `DOCTOR-OK`
* `TRUE-SELFHOST-MIN-OK`
* `[OK] byte-identical gen3 == gen4`, `GEN3-OK`
* `NATIVE-TEST-OK` (511 `[OK]` lines), including
  `[OK] sxbuild: doctor, inventory (0 non-anchor C/H files), and 3-backend parity verified C-free`
* exit 0 after 29m56s.

Additional targeted runs with the final Makefile:

* `make test-ci-shape` — OK
* `make test-stdlib-csv` — OK (seed-min == gen2 == native_aot, 44 values)
* `make test-sxbuild` — OK, `native_aot.c present: 0`, `non-anchor .c/.h files: 0`
* `make all-sayanox` still refuses an all-in-Sayanox claim.
* Modified `sxbuild` compiled by `sxc_native`; a simulated transient
  `gate-binaries/*.c` is skipped while an ordinary `other/*.c` is still
  counted.
