# Self-Hosting Sayanox - Phase 1

This directory contains the first steps toward a self-hosting Sayanox compiler.

## Goal
Eventually rewrite the entire Sayanox compiler in Sayanox itself so that:

```
sayanox compiler.sa -o compiler
```

can produce a new compiler binary.

## Phase 1 (Current)
- Define a **minimal subset** of Sayanox that is powerful enough to express a simple lexer and parser.
- Write the first pieces of a self-hosted frontend in pure Sayanox.
- Keep the Rust bootstrap compiler as the host until the self-hosted version is complete.

## Minimal Subset for Self-Hosting
The self-hosted compiler will initially support only:

- `show`, `hold`, `make`/`give`
- `when` / `otherwise`
- `while`
- Basic arithmetic and comparisons
- Arrays (for token lists)
- Simple structs (for Token, AST nodes)

## Files
- `minimal_lexer.sa` – First experimental self-hosted lexer sketch
- More files will be added as the subset grows.

## How to progress
1. Stabilize the Rust bootstrap (current C backend).
2. Implement the minimal subset completely and reliably.
3. Port lexer → parser → codegen one module at a time into Sayanox.
4. Once the self-hosted compiler can compile itself, switch the default.
