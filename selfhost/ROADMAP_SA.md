# Moving the compiler into Sayanox (.sa)

## Steps

| Step | File | Status |
|------|------|--------|
| 1 Lexer | `selfhost/lexer.sa` | DONE |
| 2 Parser | `selfhost/parser.sa` | DONE |
| 3 Codegen | `selfhost/codegen.sa` | DONE |
| 4 Full loop | more statements / self-compile | next |

## Run

```bash
./selfhost/step1_lexer.sh
./selfhost/step2_parser.sh
./selfhost/step3_codegen.sh
```

Step 3 expected: emitted binary prints `42`

## What Step 3 proves

Lex + parse + **emit C** are implemented in **Sayanox** (`.sa`), then Stage-2 only bootstraps that `.sa` once.
