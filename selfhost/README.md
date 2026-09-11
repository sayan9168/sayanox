# Self-Hosting Sayanox — Phase 5

## Goal

One Sayanox program that runs the full pipeline:

**source text → lexer → parser (AST) → C codegen**

## Files

| File | Role |
|------|------|
| `compiler.sa` | **Unified driver (Phase 5)** |
| `lexer.sa` | Standalone lexer (Phase 2) |
| `ast.sa` | AST demo (Phase 3) |
| `parser.sa` | Standalone parser (Phase 3) |
| `codegen.sa` | Standalone codegen (Phase 4) |
| `pipeline.sa` | Tiny tokens→AST→C (Phase 4) |

## Run the self-hosted compiler

```bash
cargo build --release
./target/release/sayanox selfhost/compiler.sa -o compiler.c
gcc compiler.c -o compiler && ./compiler
```

It compiles the built-in demo source `"show 42"` and prints generated C.

## What works

- Character scan of source
- Token list + number values
- AST via parallel arrays
- C emission for `show` / `hold` / `give`

## Still limited

- Nested loop control in lexer (long identifiers/numbers)
- Full keyword matching (first-letter heuristic)
- Binary expressions / blocks / make
- Reading source from a real file (needs I/O builtins)
- Writing output to a `.c` file from Sayanox itself

## Roadmap

| Phase | Status |
|-------|--------|
| 2 Lexer | ✅ |
| 3 AST + parser | ✅ |
| 4 Codegen | ✅ |
| 5 Unified driver | ✅ |
| 6 File I/O + richer language | 🚧 |
| 7 True bootstrap | 🚧 |
