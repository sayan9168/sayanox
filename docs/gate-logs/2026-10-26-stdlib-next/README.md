# 2026-10-26 — the next stdlib batch: url, datetime, hash

Branch `arena/ce16cdf8-sayanox`, based on `main` at `c7668d0` (the CI/CD
repair increment). This is the "next features" increment: three new
portable Sayanox standard-library modules, one gate, and an independent
oracle for every expected value.

## What landed

| Module | Prefix | What it adds |
|---|---|---|
| `stdlib/url.sa` | `surl_` | Percent-encoding/decoding (`surl_encode`, `surl_decode`, `surl_decode_ok`) and packed query strings (`surl_query_parse`, `surl_query_write`, `surl_query_push`, `surl_query_count`, `surl_query_key`, `surl_query_value`, `surl_query_get`, `surl_query_has`, `surl_query_empty`). |
| `stdlib/datetime.sa` | `dt_` | Proleptic Gregorian calendar, years 1..9999: `dt_is_leap`, `dt_days_in_month`, `dt_valid`, `dt_jdn`, `dt_from_jdn`, `dt_weekday`, `dt_weekday_name`, `dt_month_name`, `dt_day_of_year`, `dt_days_between`, `dt_add_days`, `dt_format`, `dt_parse`, `dt_istr`. |
| `stdlib/hash.sa` | `sh_` | Non-cryptographic checksums: `sh_sum_bytes`, `sh_is_digits`, `sh_poly`, `sh_djb2`, `sh_poly131`, `sh_sdbm`, `sh_adler32` (RFC 1950), `sh_luhn_sum`, `sh_luhn_check_digit`, `sh_luhn_valid`, `sh_istr`. |

Design constraints honoured (see `docs/STDLIB.md`):

* No string-valued list elements — the dialect refuses them — so query strings
  use the same `<len>:<bytes>` packed representation as `cli.sa` and `csv.sa`.
* No bitwise operators, no late builtins, no platform APIs. `hash.sa` works
  modulo the 31-bit prime 2147483647, keeping every product under 2^53.
* `datetime.sa` computes the forward Julian Day Number and inverts it by
  binary search over years plus a month scan that calls the forward function,
  so the two cannot disagree.
* Invalid input is refused, not guessed: bad percent escapes, `%00`, invalid
  dates, non-digit Luhn payloads, out-of-range lookups.
* Every helper is defined before its callers; every accumulation goes through
  a `hold`; no comment contains an unbalanced quote character. `short` was
  avoided as a variable name because the generated C would use a C keyword.

## The gate and its oracle

`make test-stdlib-next` (a prerequisite of `native-test`) compiles three
fixtures — `selfhost/stdlib_{url,datetime,hash}_test.sa` — on seed-min, gen2
and native_aot, and requires all three outputs to be byte-identical to each
other **and** to `selfhost/stdlib_{url,datetime,hash}.want`.

The `.want` files were computed by a host-side Python oracle using standard
libraries, not by running the Sayanox modules:

* `urllib.parse.quote` / `unquote` for percent-encoding and decoding;
* `datetime.date` / `calendar` for JDN, leap years, weekday, day-of-year and
  date formatting;
* `zlib.adler32` for Adler-32;
* hand-written Python reimplementations of the rolling hashes, sdbm and Luhn
  (independent of the `.sa` code).

106 `label=value` lines are pinned (39 url + 43 datetime + 24 hash). The gate
additionally checks that each module stands alone and that `csv_`, `surl_`,
`dt_` and `sh_` coexist in one spliced program. With `csv.sa`'s 44 values the
portable stdlib now has 150 oracle-pinned values.

One real bug was found this way: `dt_istr` initially returned an empty string
for negative numbers, so `jdn.bad=-1`, `doy.bad=-1` and `between.neg=-366`
were blank. It now handles a sign prefix, and the oracle matches.

## Verification

* `make doctor` — `DOCTOR-OK`
* `make true-selfhost` — `TRUE-SELFHOST-MIN-OK`
* `make test-stdlib-next` — OK, 106 values, seed-min == gen2 == native_aot
* `make test-stdlib-csv` — OK (previous increment, unchanged)
* `make test-ci-shape` — OK
* `make test-sxbuild` — OK, `non-anchor .c/.h files: 0`
* `make test-language-deps` — OK (no awk/sed recipes, no `.sh` files added)
* `make all-sayanox` still refuses an all-in-Sayanox claim.
* `make gen3` / `make native-test` — full chain re-run for this increment
  (see the CI run on the pull request for the runner-side proof).

## Still open

These are library additions, not a language change. The open roadmap rows are
unchanged: full-language self-host in seed-min, the pinned C seed, top-level
make/sh wrappers, seed list GC completeness, an IDE-complete LSP, full
ARM64/RV64GC runtime, namespacing in the compiler, and `.sa` on GitHub.
`hash.sa` is deliberately **not** a cryptographic module; `stdlib/crypto.sa`
remains the SHA-256/HMAC implementation.
