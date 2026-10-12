# Standard library (stdlib/)

Four modules, split by what they need from the compiler. Every helper is
checked by a `make` target; the backend columns below say what is verified.

| Module | Helpers | Backends | Gate |
|---|---|---|---|
| `stdlib/tiny.sa` | 36 `make` definitions: 31 public numeric helpers and 5 internal recursion helpers (`no_factor_from`, `rev_num`, `has_sq_from`, `div_floor`, `isqrt_from`) | seed-min, gen2, native | `test-stdlib`, `test-stdlib-growth` |
| `stdlib/str_util.sa` | 14 string helpers (`s_len`, `s_at`, `s_join`, `s_prefix`, `s_suffix`, `s_reverse`, `s_repeat`, `s_count`, `s_contains`, `s_eq`, `s_upper`, `s_lower`, `s_starts`, `s_ends`) | seed-min, gen2, native | `test-stdlib` |
| `stdlib/list_util.sa` | 9 list helpers (`l_len`, `l_get`, `l_sum`, `l_max`, `l_min`, `l_count`, `l_contains`, `l_reverse`, `l_range`) | seed-min, gen2, native | `test-stdlib` |
| `stdlib/file_util.sa` | 5 file helpers (`f_read`, `f_write`, `f_size`, `f_exists`, `f_lines`) | seed-min, gen2, native | `test-stdlib` |

## Why two kinds of module

`tiny.sa` uses only numbers, `when`, `give` and recursion. That is the subset
all three backends implement, so it is the only library that can be promised on
all three. The other three modules take `str` and `list` parameters
(`make s_len(s: str) -> num`). Typed parameters are a full-language feature:
the seed refuses them, and native rejects them with `bad param list`. Those
modules are for gen2-compiled programs, and the test checks that the other two
backends refuse them rather than miscompile them.

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
