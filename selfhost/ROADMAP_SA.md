# Moving the compiler into Sayanox (.sa)

Goal: less C/Rust, more `.sa` so the language owns its compiler.

## Steps

| Step | File | Status |
|------|------|--------|
| 1 Lexer | `selfhost/lexer.sa` | DONE |
| 2 Parser | `selfhost/parser.sa` | next |
| 3 AST + codegen | `selfhost/codegen.sa` | later |
| 4 Full loop | `.sa` compiler compiles itself | later |

## Run Step 1

```bash
./selfhost/step1_lexer.sh
```

Expected: IDENT, NUMBER 42, tokens 2
