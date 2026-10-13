# Standard library (stdlib/)

Seven modules, split by what they need from the compiler. Every helper is
checked by a `make` target; the backend columns below say what is verified.

| Module | Helpers | Backends | Gate |
|---|---|---|---|
| `stdlib/tiny.sa` | 36 `make` definitions: 31 public numeric helpers and 5 internal recursion helpers (`no_factor_from`, `rev_num`, `has_sq_from`, `div_floor`, `isqrt_from`) | seed-min, gen2, native | `test-stdlib`, `test-stdlib-growth` |
| `stdlib/str_util.sa` | 14 string helpers (`s_len`, `s_at`, `s_join`, `s_prefix`, `s_suffix`, `s_reverse`, `s_repeat`, `s_count`, `s_contains`, `s_eq`, `s_upper`, `s_lower`, `s_starts`, `s_ends`) | seed-min, gen2, native | `test-stdlib` |
| `stdlib/list_util.sa` | 9 list helpers (`l_len`, `l_get`, `l_sum`, `l_max`, `l_min`, `l_count`, `l_contains`, `l_reverse`, `l_range`) | seed-min, gen2, native | `test-stdlib` |
| `stdlib/file_util.sa` | 5 file helpers (`f_read`, `f_write`, `f_size`, `f_exists`, `f_lines`) | seed-min, gen2, native | `test-stdlib` |
| `stdlib/num_util.sa` | 17 untyped numeric helpers (`nu_trunc`, `nu_floor`, `nu_ceil`, `nu_round`, `nu_frac`, `nu_min`, `nu_max`, `nu_mod_pos`, `nu_int_div`, `nu_wrap`, `nu_map_range`, `nu_avg`, `nu_median3`, `nu_pi`, `nu_deg2rad`, `nu_rad2deg`, `nu_turn`) | seed-min, gen2, native | `test-stdlib-modules` |
| `stdlib/list_algo.sa` | 17 typed list algorithms (`la_insert_sorted`, `la_sort`, `la_sorted`, `la_index_of`, `la_append`, `la_slice`, `la_take`, `la_drop`, `la_cumsum`, `la_repeat`, `la_scale`, `la_offset`, `la_zip_add`, `la_count_gt`, `la_remove_at`, `la_insert_at`, `la_distinct`) | seed-min, gen2, native | `test-stdlib-modules` |
| `stdlib/str_text.sa` | 18 typed byte-string helpers (`t_is_space_byte`, `t_is_digit_byte`, `t_index_of`, `t_last_index_of`, `t_slice`, `t_trim_left`, `t_trim_right`, `t_trim`, `t_cmp`, `t_is_digits`, `t_pad_left`, `t_pad_right`, `t_word_count`, `t_replace`, `t_remove`, `t_hash`, `t_parse_uint`, `t_uint_str`) | seed-min, gen2, native | `test-stdlib-modules` |

## Why two kinds of module

`tiny.sa` and `num_util.sa` use only numbers, `when`, `give` and recursion.
That is the subset all three backends implement in full, so those two are the
modules that can be promised on the native-AOT path without typed parameters.

The other five modules take `str` and `list` parameters
(`make s_len(s: str) -> num`). Typed parameter and return annotations are now
accepted by seed-min, gen2 and native alike (checked on 2026-10-13 with a
`greet(name: str) -> str` / `total(xs: list) -> num` probe: seed-min and native
both print the right answer). What still differs is a gen2 gap in `give`:

* `hold q = "hi " + name` works on gen2, but a bare `give "hi " + name` inside
  a function body emits `char * + char *` and fails to compile. Library code
  therefore accumulates into a `hold` and returns that; it never puts a string
  `+` chain directly in a `give`. The C compile error is loud rather than
  silent, and the gap is listed under "Measured divergences" in
  `docs/STATUS.md`.

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
`<0 / 0 / >0`, `t_word_count` counts whitespace-separated runs, `t_replace`
replaces every non-overlapping occurrence left to right (an empty `find`
returns the input unchanged), `t_hash` is a small `h * 31 + c` fold, and
`t_parse_uint` stops at the first non-digit.

### Rules these modules follow

* One statement per line; `give xs }` on one line is rejected.
* A helper is defined before every helper that calls it — a user function gets
  no forward prototype in the generated C.
* `give xs[i]` does not compile; bind with `hold v = xs[i]` first.
* **An index may be a numeric expression** (`xs[i - 1]`, `xs[(a + b) / 2]`,
  `xs[p.k]`) in a value position, inside a `when`/`while` condition and inside
  a `for` bound, on all three backends since the 2026-10-13 increment
  (`make test-gen2-index-expr`). `la_sorted` uses `xs[i] < xs[i - 1]` and is
  the live stdlib exercise for it. Still refused by gen2 inside `[ ]`, with a
  clear diagnostic: `%`, any call including `len()`, a nested index, a comma, a
  quoted string, an empty index, unbalanced parentheses and an expression that
  ends with an operator. Bind the value with `hold` first -- that is what
  `last_char` in the fixture does instead of `text[len(text) - 1]`.
* No inline list literal as a call argument and no postfix indexing of a call
  result (`la_take(xs, 2)[1]`) in tests: bind to a `hold` first.
