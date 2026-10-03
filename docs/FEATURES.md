# Feature matrix

Only what was actually verified (see `docs/STATUS.md` for the full table and
`make true-selfhost` / `make gen3` / `make native-test` for reproduction).

| Feature | Example | seed-min | gen2 | native |
|---------|---------|----------|------|--------|
| hold / show | `hold x = 42` · `show x` | yes | yes | yes |
| when / else / otherwise | `when a > 5 { } else { }` | yes | yes | yes |
| while | `while n < 3 { }` | yes | yes | yes |
| arithmetic | `+ - * / %` | yes | yes | yes |
| make / give | `make f(a) { give a + 1 }` | yes | yes | no (error) |
| recursion | `give n * fac(n - 1)` | yes | yes | no (error) |
| lists | `[10,20]` · `xs[0]` · `len(xs)` · `push(xs, v)` | yes | yes | no (error) |
| structs (numeric) | `Point { x: 3, y: 4 }` · `p.x` | yes | yes | no (error) |
| strings | `show "hi"` · `concat(a,b)` · `chr(n)` · `sx_index(s,i)` | yes | yes | `show "str"` |
| modules | `use "file.sa"` | yes | yes | no (error) |

Not implemented anywhere (do not claim otherwise): `for`/`for-in`, `elif`,
`read()`, `abs`/`pow`/`contains`/`startswith`/`repeat`, type tags, `substr`,
`gc`, namespaced `export`/`use`, string struct fields, nested structs, a
standard library.
