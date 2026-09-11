# Self-Hosting Sayanox — Phase 2.0

## Goal

Bootstrap the Sayanox compiler in Sayanox itself.

## Current Phase: 2.0

### Lexer (`lexer.sa`)
- Character-by-character scan of source text
- Uses `len`, string indexing (char codes), `push`, `while`, `when`
- Recognizes: whitespace, numbers, identifiers/keywords (by first letter), operators

### Parser (`parser.sa`)
- Minimal recursive-style statement walker
- Handles `show`, `hold`, `make` token sequences
- Demo token stream for `show 42`

## Still needed for full self-hosting

1. String builder (collect full identifiers / string literals)
2. Nested loops without overshoot (richer control flow)
3. Structs for Token `{ kind, value }` and AST nodes
4. Full expression / block parsing
5. Codegen ported to Sayanox
6. Ability to run `.sa` compiler files producing C or native output

## Run with bootstrap compiler

```bash
cargo build --release
./target/release/sayanox selfhost/lexer.sa -o lexer.c
gcc lexer.c -o lexer && ./lexer

./target/release/sayanox selfhost/parser.sa -o parser.c
gcc parser.c -o parser && ./parser
```

## Roadmap

- Phase 2.x — richer lexer (full keywords, strings)
- Phase 3 — AST structs + full parser
- Phase 4 — codegen in Sayanox
- Phase 5 — self-host (compiler compiles itself)
