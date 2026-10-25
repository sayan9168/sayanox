# Standard library (stdlib/)

Ten modules, split by what they need from the compiler. Every helper is
checked by a `make` target; the backend columns below say what is verified.

| Module | Helpers | Backends | Gate |
|---|---|---|---|
| `stdlib/tiny.sa` | 36 `make` definitions: 31 public numeric helpers and 5 internal recursion helpers (`no_factor_from`, `rev_num`, `has_sq_from`, `div_floor`, `isqrt_from`) | seed-min, gen2, native | `test-stdlib`, `test-stdlib-growth` |
| `stdlib/str_util.sa` | 14 string helpers (`s_len`, `s_at`, `s_join`, `s_prefix`, `s_suffix`, `s_reverse`, `s_repeat`, `s_count`, `s_contains`, `s_eq`, `s_upper`, `s_lower`, `s_starts`, `s_ends`) | seed-min, gen2, native | `test-stdlib` |
| `stdlib/list_util.sa` | 9 list helpers (`l_len`, `l_get`, `l_sum`, `l_max`, `l_min`, `l_count`, `l_contains`, `l_reverse`, `l_range`) | seed-min, gen2, native | `test-stdlib` |
| `stdlib/file_util.sa` | 5 file helpers (`f_read`, `f_write`, `f_size`, `f_exists`, `f_lines`) | seed-min, gen2, native | `test-stdlib` |
| `stdlib/num_util.sa` | 17 untyped numeric helpers (`nu_trunc`, `nu_floor`, `nu_ceil`, `nu_round`, `nu_frac`, `nu_min`, `nu_max`, `nu_mod_pos`, `nu_int_div`, `nu_wrap`, `nu_map_range`, `nu_avg`, `nu_median3`, `nu_pi`, `nu_deg2rad`, `nu_rad2deg`, `nu_turn`) | seed-min, gen2, native | `test-stdlib-modules` |
| `stdlib/list_algo.sa` | 21 typed list algorithms (`la_insert_sorted`, `la_sort`, `la_sorted`, `la_index_of`, `la_append`, `la_slice`, `la_take`, `la_drop`, `la_cumsum`, `la_repeat`, `la_scale`, `la_offset`, `la_zip_add`, `la_count_gt`, `la_remove_at`, `la_insert_at`, `la_distinct`, `la_lower_bound`, `la_upper_bound`, `la_merge_sorted`, `la_rotate`) | seed-min, gen2, native | `test-stdlib-modules` |
| `stdlib/str_text.sa` | 18 typed byte-string helpers (`t_is_space_byte`, `t_is_digit_byte`, `t_index_of`, `t_last_index_of`, `t_slice`, `t_trim_left`, `t_trim_right`, `t_trim`, `t_cmp`, `t_is_digits`, `t_pad_left`, `t_pad_right`, `t_word_count`, `t_replace`, `t_remove`, `t_hash`, `t_parse_uint`, `t_uint_str`) | seed-min, gen2, native | `test-stdlib-modules` |
| `stdlib/json_util.sa` | flat-object JSON build/read (`j_escape`, `j_kv_text`, `j_kv_number`, `j_kv_flag`, `j_pair`, `j_obj`, `j_arr_numbers`, `j_has`, `j_get_text`, `j_get_number`, `j_get_flag`) | seed-min, gen2, native | `test-stdlib-modules` |
| `stdlib/json_deep.sa` | nested JSON reader, any depth (`jd_valid`, `jd_type`, `jd_has`, `jd_raw`, `jd_text`, `jd_num`, `jd_flag`, `jd_len`, `jd_key`); dotted paths with `[i]` indexes, 15 pinned refusals, agrees with `json_util.sa` on flat objects | seed-min, gen2, native | `test-stdlib-json-deep` |
| `stdlib/json_write.sa` | nested JSON writer, functional object mutator (`jw_obj_set`, `jw_obj_del`), minifier (`jw_minify`) and multi-level pretty-printer (`jw_pretty`), round-tripping through `json_deep.sa` | seed-min, gen2, native | `test-stdlib-json-write` |
| `stdlib/crypto.sa` | SHA-256 and HMAC-SHA256 (`cx_sha256`, `cx_sha256_list`, `cx_sha256_raw`, `cx_hmac`, `cx_hmac_list`, `cx_hmac_raw`, `cx_hex`, `cx_hex_byte`, `cx_unhex`, `cx_bytes`, `cx_eq_hex`); FIPS 180-4 and RFC 4231 vectors, cross-checked against `sha256sum` when it is installed | seed-min, gen2, native | `test-stdlib-crypto` |

## Why two kinds of module

`tiny.sa` and `num_util.sa` use only numbers, `when`, `give` and recursion.
That is the subset all three backends implement in full, so those two are the
modules that can be promised on the native-AOT path without typed parameters.

The other eight modules take `str` and `list` parameters
(`make s_len(s: str) -> num`). Typed parameter and return annotations are now
accepted by seed-min, gen2 and native alike (checked on 2026-10-13 with a
`greet(name: str) -> str` / `total(xs: list) -> num` probe: seed-min and native
both print the right answer). A bare string `+` chain in a `give`
(`give "hi " + name`) used to emit `char * + char *` on gen2; that lowering
was fixed on 2026-10-13 (`test-gen2-expr-lowering`), but library code still
accumulates into a `hold` and returns that, because the pattern works on
every backend and every older gen2. One gen2 authoring rule remains load
-bearing for these modules: a comment must not contain an odd number of raw
`"` characters — gen2's typed-signature scan loses track of quotes there and
misreads the following `make` signatures (this was the actual root cause of
the `json_util.sa` gen2 failure, found 2026-10-13; balanced quotes in
comments are fine).

## Rules for adding a helper to tiny.sa

* Numbers only. These helpers avoid `hold` inside a body (native now supports it). At most 6
  parameters.
* Define a helper before any helper that calls it. A user function gets no
  forward prototype in the generated C.
* Add the expected output to a checked-in program and to a `make` target that
  requires seed-min, gen2 and native to print the same bytes. The 2026-10-10
  additions are in `selfhost/stdlib_growth_test.sa`, and their expected values
  were worked out by hand.

## Use

```sayanox
use "stdlib/tiny.sa"
show isqrt(50)        // 7
show collatz_steps(6) // 8
```

`use` is resolved relative to the file that contains it.

## `json_util.sa`: flat-object JSON, deliberately small (2026-10-13)

`j_` builds and reads **flat** JSON objects: string/number/boolean values,
plus number arrays (`j_arr_numbers`). `j_get_text`, `j_get_number` and
`j_get_flag` read the *first* `"key":` occurrence, `j_has` tests presence,
and the builders escape quotes, backslashes and control bytes. Verified
byte-identically on seed-min, gen2 and native by `test-stdlib-modules`
(`selfhost/stdlib_json_test.sa`, expected values computed by hand).

Documented non-goals, by design: nested objects/arrays as values, exponent
notation in numbers, and `\u` escapes above U+007F on the read path. A JSON
document outside that shape is not silently misread into a wrong answer the
library claims is right — it is simply outside what these helpers promise,
and this section is the promise.

## Portable interpolation helpers (2026-10-11)

`tiny.sa` adds `lerp(a,b,t)`, `saturate(x)`, `smoothstep01(x)` and
`distance_sq(x1,y1,x2,y2)`. All accept numbers and work on seed-min, gen2 and
native. `lerp` intentionally extrapolates for t outside [0,1]; `saturate`
clamps to [0,1]; `smoothstep01` clamps before applying x*x*(3-2*x).
`distance_sq` returns squared Euclidean distance, not distance. These use
double arithmetic (no promise against overflow or NaN propagation).

`test-stdlib-interpolation`, included by `test-stdlib` and `test-stdlib-growth`,
checks endpoints, fractions, extrapolation and distance on seed/gen2, and
native when built. This is a small utility library, not a full standard
library: no JSON, HTTP or cryptography implementation is added here.

## Algorithm and text modules (2026-10-13)

Three modules add 52 helpers, all in `make test-stdlib-modules`. The expected
output is 99 hand-computed values from `selfhost/stdlib_modules_test.sa`, and
seed-min, gen2 and native must print byte-identical stdout.

**`num_util.sa` (`nu_`)** — numeric helpers that need no `str` or `list`
parameter, so they run on the native-AOT subset too. The only double-to-integer
conversion the pure-min dialect offers is truncation-toward-zero through the
modulo operator (`x % 1000000000000000` truncates the fractional part because
`sx_mod` casts both operands to `long`), and every rounding helper here is
built on that one fact:

```sayanox
make nu_trunc(x) {
  give x % 1000000000000000
}
```

`nu_floor`/`nu_ceil`/`nu_round`/`nu_frac` derive from it, `nu_mod_pos` is
Euclidean modulo (the result takes the sign of the divisor, unlike `%`),
`nu_int_div` is floor division, `nu_wrap` folds a value into `[lo, hi]`,
`nu_map_range` rescales one interval onto another, `nu_median3` is the median of
three, and `nu_pi`/`nu_deg2rad`/`nu_rad2deg`/`nu_turn` cover angles.
`show` prints with `%g`, so `nu_pi()` displays as `3.14159`.

**`list_algo.sa` (`la_`)** — typed list algorithms. Every transform returns a
NEW list; none of them mutates its argument, and the fixture re-checks the
input length after each call. `la_sort` is insertion sort (`la_insert_sorted`
does one step), `la_sorted` reports whether a list is non-decreasing,
`la_slice`/`la_take`/`la_drop` clamp out-of-range indices instead of failing,
`la_distinct` keeps first occurrences, and `la_zip_add` stops at the shorter
list.

**`str_text.sa` (`t_`)** — typed, byte-oriented text helpers. Strings are C
`char *`; a "character" is one byte, so these helpers are ASCII-oriented and
will split a multi-byte UTF-8 sequence (the same limitation `str_util.sa`
documents). `t_index_of`/`t_last_index_of` return `-1` when absent, `t_slice`
clamps, `t_trim*` strip ASCII space/tab/newline/CR, `t_cmp` gives
`<0 / 0 / >0`, `t_word_count` counts whitespace-separated runs, `t_replace(s, from, to)` replaces each matching byte, not substrings, `t_hash` is a small `h * 31 + c` fold, and
`t_parse_uint` stops at the first non-digit.

### Rules these modules follow

* One statement per line; `give xs }` on one line is rejected.
* A helper is defined before every helper that calls it — a user function gets
  no forward prototype in the generated C.
* Bind intermediate indexed values with `hold` in portable library code;
  direct indexed returns now have their own `test-give-index` coverage.
* **An index may be a numeric expression** (`xs[i - 1]`, `xs[(a + b) / 2]`,
  `xs[p.k]`) in a value position, inside a `when`/`while` condition and inside
  a `for` bound, on all three backends since the 2026-10-13 increment
  (`make test-gen2-index-expr`). `la_sorted` uses `xs[i] < xs[i - 1]` and is
  the live stdlib exercise for it. Gen2 also supports modulo, len() and
  nested indexes; arbitrary calls, comma/string/empty indexes, unbalanced
  parentheses and trailing operators remain refused. See
  `test-gen2-index-expr` and `test-gen2-expr-lowering` for the exact boundary.
* No inline list literal as a call argument and no postfix indexing of a call
  result (`la_take(xs, 2)[1]`) in tests: bind to a `hold` first.

## Scope confirmation (2026-10-15, superseded 2026-10-22 for two items)

No nested JSON reader is provided.
`json_util` remains text building plus limited flat-object extraction, not a
validating JSON parser. It does not promise nested values, exponent parsing,
Unicode scalar validation or arbitrary escaped-key lookup. Existing module
parity tests run in the bootstrap gates; no crypto implementation is claimed.

> Superseded on 2026-10-22 by `stdlib/json_deep.sa` and `stdlib/crypto.sa`
> (see "Nested JSON and cryptography" below). The sentences above still
> describe `json_util.sa` itself, which was not changed: it is still the flat,
> non-validating module. What changed is that two *new* modules now cover the
> nested-JSON and hashing cases, each with its own gate.
HTTP/crawler integration tests are explicitly optional (`make test-network`):
they use a Python local test server and curl and are not bootstrap dependencies.
The optional HTTP builtin's implementation is not a pure-.sa HTTP/TLS stack.

## Offline list algorithms (2026-10-16)

Four real `.sa` helpers extend the existing standalone `list_algo` module:

| Helper | Contract | Cost |
|---|---|---|
| `la_lower_bound(xs, v)` | First index with value >= v, or `len(xs)` | O(log n) comparisons |
| `la_upper_bound(xs, v)` | First index with value > v, or `len(xs)` | O(log n) comparisons |
| `la_merge_sorted(a, b)` | Fresh sorted merge, retains duplicates; equal values taken from a first | O(n + m) elements |
| `la_rotate(xs, shift)` | Fresh left rotation; negative shifts rotate right; reduced modulo length | O(n) elements |

Bounds and merge require ascending sorted input with finite numeric values;
there is no sortedness validation or NaN/Infinity total-order promise. Bound
indices are insertion positions in `[0, len(xs)]`, not -1 sentinels. Merge
accepts empty lists and aliased inputs. Rotation requires integer shifts within
the runtime's signed-integer modulo range; empty input avoids modulo zero.
Fresh results never alias an input, including zero rotations and empty-side
merges. No helper changes input elements or list length.

`make test-stdlib-list-search` requires **all three** seed-min/Gen2/native
backends (no native skip), compiles C with strict pointer/prototype diagnostics,
and checks exact output against an independent expected success marker. The
fixture checks explicit bound positions plus a small-domain linear oracle,
duplicates, missing endpoints, negative values, empty/singleton inputs, merge
contents, negative/wrapped shifts, and input preservation after result pushes.
The gate is included by `test-stdlib-modules` (therefore `test-stdlib` and
`test-stdlib-growth`) and `native-test`. Existing module/JSON fixtures remain.
Logs: [2026-10-16 offline stdlib](gate-logs/2026-10-16-stdlib/).

### Explicit non-goals

This remains a **small utility library, not a full standard library**. No
JSON printer for nested values, Unicode text model,
heterogeneous lists, filesystem metadata API or pure-.sa HTTP/TLS stack is
added. `json_util` remains flat and non-validating; `f_exists`
means readable **and nonempty**, not filesystem existence (empty/missing files
are indistinguishable there). `t_hash` is non-cryptographic. HTTP/network
examples and their optional dependencies stay outside required bootstrap gates.
The new module code and tests use no network or interpreter dependency.

Two items left this list on 2026-10-22: nested JSON *reading*
(`stdlib/json_deep.sa`) and cryptographic hashing (`stdlib/crypto.sa`). Writing
nested JSON is still not provided, and the non-goals above are otherwise
unchanged.

## Nested JSON and cryptography (2026-10-22)

Two modules, both written in the dialect all three backends accept, both
checked on all three backends by their own gate.

### `stdlib/json_deep.sa` -- reading nested JSON

`jd_*` reads a value at a **path**: `"user.name"`, `"items[2].id"`,
`"a.b[0][1].c"`. Nine helpers: `jd_valid` (whole-document check), `jd_type`
(`object`/`array`/`string`/`number`/`bool`/`null`/`none`), `jd_has`, `jd_raw`
(the exact source slice of the value), `jd_text` (a string value, escapes
decoded, `\uXXXX` folded to UTF-8), `jd_num`, `jd_flag`, `jd_len` (members of
an object, elements of an array, bytes of a string) and `jd_key` (the i-th key
of an object, for walking a document whose keys are not known in advance).

What it refuses is as pinned as what it accepts: `test-stdlib-json-deep`
checks 8 accepted documents (including `null`, `-0.5e+10`, `[]`, `{}` and
`[[[[1]]]]`) and **15 refusals** -- empty input, a trailing comma in an object
and in an array, an unterminated array, a missing colon, an unquoted key,
trailing text after a complete value, the numbers `01`, `1.` and `1e`, a
missing value after a colon, the truncated literal `tru`, an unknown `\x`
escape, and the mismatched closers `[1}` and `{"a":1}}`. The same gate feeds flat objects
through both `json_util.sa` and `json_deep.sa` and requires the two to agree,
so the new module cannot drift away from the old one on the cases both cover.

Not provided: writing nested JSON (`json_util.sa` still builds flat objects
only), mutation, pretty-printing, duplicate-key policy beyond "first wins", or
numbers outside what the runtime's double can hold.

### `stdlib/crypto.sa` -- SHA-256 and HMAC-SHA256

`cx_sha256(text)` and `cx_hmac(key, text)` answer lower-case hex; the `_list`
forms take byte lists, so data that is not valid text (or that contains a zero
byte, which a Sayanox string cannot carry) still hashes; the `_raw` forms
answer a byte list. `cx_hex`, `cx_hex_byte`, `cx_unhex` and `cx_bytes` convert
between the three representations, and `cx_eq_hex` compares two digests
without caring about letter case.

The implementation is pure arithmetic: the dialect the seed accepts has no
bitwise operators, so the 32-bit words are carried as numbers and the
rotations, shifts, `and`, `or`, `xor` and `not` of the algorithm are done with
division and remainder. That is slower than a `uint32_t` implementation and it
is the price of running on all three backends.

`test-stdlib-crypto` checks the FIPS 180-4 vectors (empty string, `abc`, the
two-block message), the padding boundaries at 55, 56, 63, 64 and 65 bytes, RFC
4231 HMAC cases 1, 2 and 3, hex round-trips, the nine bit primitives, and a
tamper fixture where one flipped byte must change the digest. When `sha256sum`
is installed the gate also compares against it; when it is not, that one check
prints `[SKIP]` and the rest still runs, because no bootstrap gate may depend
on a tool outside the minimal set.

This module provides SHA-256 and HMAC-SHA256 primitives (`tools/sxpkg` uses it
for package digests and symmetric keyed signatures). Asymmetric signatures live
in `stdlib/pubkey.sa` below.

### `stdlib/pubkey.sa` -- Curve25519 Schnorr-SHA256 public-key signatures

`stdlib/pubkey.sa` implements portable pure-Sayanox asymmetric key derivation,
deterministic Schnorr signing, and public-key-only verification on the twisted
Edwards curve `-x^2 + y^2 = 1 + d*x^2*y^2` over `GF(2^255 - 19)` using the
RFC 8032 Ed25519 basepoint `B` and prime subgroup order `L`:

* `pk_seed_from_passphrase(pass)` / `pk_pubkey(seed_hex)` / `pk_keyid(pub_hex)`
* `pk_sign(seed_hex, msg)` -> 128-hex `(R || S)` deterministic signature
* `pk_verify(pub_hex, msg, sig_hex)` -> `1` iff `S < L`, `A` and `R` decode to
  canonical curve points, and `[8*S]B == [8]R + [8*e]A` (never touches the
  secret seed)

`make test-sxpkg-pubkey` pins 3-way native parity (`seed-min == gen2 == native_aot`)
on `selfhost/stdlib_pubkey_test.sa` plus end-to-end `sxpkg` package (`pubsig=`)
and index (`INDEX.sig`) verification with `.sec` deleted. Arithmetic uses 16-bit
limbs inside IEEE-754 doubles (exact below `2^53`), with no constant-time
side-channel claim.
