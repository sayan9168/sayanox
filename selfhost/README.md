# Stage 2 — Generic full-language subset lowering

## Supported (generic)

- `show <expr>`
- `hold name = <expr>`
- `when <expr> { ... } otherwise { ... }`
- `while <expr> { ... }`
- expressions: numbers, strings, idents, `+ - * /`, comparisons, `( )`
- `//` comments
- builtins (limited): `str`, `len`

## Also

- `compiler.sa` → full **semantic** Stage-1-equivalent C compiler

## Not complete

- Full `make` function body lowering (skipped)
- `read_file` / `write_file` / `push` runtime in Stage-2 output
- Arrays / structs

## Run

```bash
./selfhost/bootstrap.sh
```
