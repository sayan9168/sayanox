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
`hold status = write_file(path, text)`). A bare builtin-call statement is a
native-AOT extension and is not part of the shared dialect. `string + number`
is also native-only; keep numeric values separate from strings in portable
pure-min programs.
