# Self-Hosting Sayanox

This directory contains the first steps toward a fully self-hosted Sayanox compiler.

## Goal

Write the entire Sayanox compiler in Sayanox itself so that:

```
sayanox compiler.sa -o compiler
```

produces a new working compiler binary.

## Current Phase: 1.2

- A realistic **minimal lexer** structure is written in pure Sayanox
  (`minimal_lexer.sa`).
- Token kinds, keyword lookup skeleton, and a demo token stream are present.
- The file clearly documents the language features that are still missing
  before a real character-by-character scanner can be finished.

## Minimal Language Subset Required for Self-Hosting

The self-hosted compiler will initially need only:

- `show`, `hold`, `make` / `give`
- `when` / `otherwise`, `while`
- Basic arithmetic and comparisons
- Arrays + indexing
- Simple structs (for Token and AST nodes)
- String indexing and character codes (coming soon)

## Roadmap

1. Stabilize the Rust bootstrap compiler (current C backend).
2. Finish the missing language features (string indexing, char codes, dynamic arrays).
3. Port the lexer completely into Sayanox.
4. Port the parser.
5. Port the code generator.
6. Achieve full self-hosting.

## Files

- `minimal_lexer.sa` – Phase 1.2 self-hosted lexer sketch
- `README.md` – this file
