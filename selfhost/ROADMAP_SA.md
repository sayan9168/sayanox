# Moving the compiler into Sayanox (.sa)

Goal: compiler logic in `.sa`, not only C/Rust.

## Steps

| Step | File | Status |
|------|------|--------|
| 1 Lexer | `selfhost/lexer.sa` | DONE |
| 2 Parser | `selfhost/parser.sa` | DONE |
| 3 Codegen | `selfhost/codegen.sa` | next |
| 4 Full loop | `.sa` compiles itself | later |

## Run

```bash
./selfhost/step1_lexer.sh
./selfhost/step2_parser.sh
```

Parser expected: `AST Show` / `42` / `parse OK`
