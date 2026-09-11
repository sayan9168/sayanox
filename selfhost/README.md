# Self-Hosting Sayanox — Phase 3

## Goal

Bootstrap the Sayanox compiler in Sayanox itself.

## Phase 3 (current)

### AST (`ast.sa`)
- Node kinds for statements and expressions
- Parallel arrays: `kind`, `left`, `right`, `value`
- `ast_new` allocates a node and returns its id

### Parser (`parser.sa`)
- Token stream + `peek` / `advance`
- `parse_primary` → number / ident
- `parse_expression`
- `parse_statement` → show / hold / give / make / when / while
- Builds a real AST for `show 42`

### Lexer (`lexer.sa`)
- Character-by-character scanner (Phase 2)

## Run

```bash
cargo build --release
./target/release/sayanox selfhost/ast.sa -o ast.c && gcc ast.c -o ast && ./ast
./target/release/sayanox selfhost/parser.sa -o parser.c && gcc parser.c -o parser && ./parser
./target/release/sayanox selfhost/lexer.sa -o lexer.c && gcc lexer.c -o lexer && ./lexer
```

## Next (Phase 4+)

1. Binary operator parsing (`+ - * /`)
2. Blocks `{ ... }`
3. Wire lexer output → parser input
4. Codegen in Sayanox (AST → C or tokens)
5. Full self-host

## Roadmap

| Phase | Content              | Status   |
|-------|----------------------|----------|
| 2.0   | Lexer + parser sketch| ✅       |
| 3.0   | AST + fuller parser  | ✅       |
| 4.0   | Codegen in Sayanox   | 🚧       |
| 5.0   | Self-host            | 🚧       |
