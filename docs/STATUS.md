# Status

Last updated: 2026-10-03

## Entry

```bash
make true-selfhost
```

## Coverage

| Feature | seed-min | gen2 |
|---------|----------|------|
| hold/show/when/while | yes | yes |
| make/give | yes | yes |
| lists + len + push | yes | yes |
| structs + field | yes | yes |
| `%` modulo | yes | yes |
| `else` | yes | yes |
| `use "file.sa"` | yes | not yet |

## Honest boundary

`%` and `else` now work on both seed-min and gen2. `compiler_min` lowers
`a % b` to `(double)((long)(a)%(long)(b))` and accepts `else` as an alias of
`otherwise` (both emit `} else {`). The earlier gen2 desync was the string
scanner: a backslash escaped the *stored* char but not the *scanned* one, so
`\"` ended the literal; all string / argv / opnd paths now consume the escaped
char too, and a `/` that starts a `//` comment is no longer taken as division.

Still not on gen2: `use "file.sa"` (modules), chained binary expressions
(`a + b + c` uses the first operator only), and `%` inside `when`/`while`
conditions (condition text is copied verbatim).

## Later

modules on gen2, string/nested fields, native lists/structs, Stage-2 parity.
