# Sayanox .sa codegen

## Supported
- Full names via hash slots (`hold count` / `hold total`)
- `make id(n) { give n }` + `show id(42)`
- `make f() { give 42 }` + `show f()`
- `show "hi"` (string literal MVP)
- when / while / otherwise / hold / show number

```bash
./selfhost/step5_all.sh
```

## Limits
- String content currently emits fixed `puts("hi")` for demos (literal scan skips body)
- struct / list emit: not in .sa codegen yet (use Stage-2 `sx` for full language)
- Name → `S[hash]` not source-level C identifiers
