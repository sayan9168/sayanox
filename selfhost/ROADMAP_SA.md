# Compiler in Sayanox (.sa) — subset complete

| Step | What | Status |
|------|------|--------|
| 1 | lexer.sa | DONE |
| 2 | parser.sa | DONE |
| 3–4.3 | codegen: hold show when while make give call | DONE |
| 5 | all demos via step5_all.sh | DONE |

```bash
./selfhost/step5_all.sh
```

## Subset (one variable `v`, one function `sx_f`)

- `hold name = number` / assign
- `show number` / `show name` / `show fn()`
- `when cond { ... }` / `while cond { ... }`
- `make fn() { give number }`

Beyond this: multi-var, params, otherwise, structs → later expansions.
Stage-2 C remains the bootstrap host for running `.sa` tools.
