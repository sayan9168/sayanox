# Builtins in the maintained pure-min subset

This table describes calls covered by the current seed-min/gen2 compiler tests.
Native AOT coverage and intentional differences are documented in
[`STATUS.md`](STATUS.md).

| Sayanox call | Purpose | seed-min | gen2 | native AOT |
|--------------|---------|----------|------|------------|
| `concat(a, b)` | concatenate strings | yes | yes | yes |
| `len(value)` | string/list length | yes | yes | yes |
| `chr(n)` | one-byte string from numeric code | yes | yes | yes |
| `string_eq(a, b)` | string equality as numeric 0/1 | yes | yes | yes |
| `sx_index(s, i)` / `s[i]` | byte at zero-based index | yes | yes | yes |
| `arg_count()` / `arg(i)` | process argument count/value | yes | yes | yes |
| `read_file(path)` | read a file as a string | yes | yes | yes |
| `write_file(path, data)` | truncate/write a file; numeric status | yes | yes | yes |
| `push(xs, value)` | append a number to a list | yes | yes | yes |

`len` accepts strings and numeric lists. List indexing is zero-based. String
indexing returns a numeric byte value; use `chr` when a one-byte string is
needed. The exact edge cases and parity tests are listed in
[`STATUS.md`](STATUS.md).

## Runtime builtins added with the collector (gen1_min / gen2)

These are compiled and run by `selfhost/gen2` (and by the `gen1_min` built from
the same source); the checked-in `seed-min` predates them and rejects them.

| Sayanox call | Purpose |
|--------------|---------|
| `read_line()` | read one line from stdin, without the newline |
| `read_n(n)` | read exactly `n` bytes from stdin |
| `write_out(s)` | write `s` to stdout without a newline |
| `flush_out()` | flush stdout |
| `numstr(n)` | format a number as a string (the `%g` form `show` uses) |
| `gc()` | run a collection now; returns the bytes reclaimed |
| `gc_live()` | bytes currently held by the managed heap |
| `gc_runs()` | number of collections so far |

All of them are ordinary expressions, so they nest inside other calls
(`concat(a, numstr(n))`) and can be stored (`hold n = numstr(v)`). Native AOT
does not implement them. See [`GC.md`](GC.md).

The maintained C backends accept the builtins in expressions (for example,
`hold status = write_file(path, text)`). A *statement* is `hold show when
while make give struct use` or a bare `push(xs, v)`; every other bare call —
`write_file(path, text)` on its own line, a user-function call — is an
`unknown statement` in seed-min, gen2 and (since 2026-10-08) native, which
used to run any bare builtin call. `string + number` is rejected by all three
for the same reason; build a message with `concat(s, n)` if a program has to
run everywhere.

## Tiny portable library: `stdlib/tiny.sa`

The repository ships one small library, used with the ordinary module splice:

```sayanox
use "stdlib/tiny.sa"

show min2(3, 7)      // 3
show max2(3, 7)      // 7
show absv(0 - 5)     // 5
show sum_to(10)      // 55   (recursive)
show pow_int(2, 10)  // 1024 (recursive)
show is_even(42)     // 1
show gcd(48, 36)     // 12   (recursive, uses %)
```

It is deliberately numeric-only: the native-AOT subset has no string-returning
functions and no list/string function parameters, so every helper here runs
unchanged on seed-min, gen2 and native (`make test-stdlib` compares their
output). Use the builtins above for string and list work. This is not a full
standard library — [`STATUS.md`](STATUS.md) records that boundary.
