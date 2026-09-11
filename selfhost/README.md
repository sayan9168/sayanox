# Self-Hosting Sayanox — Phase 4

## Goal

Bootstrap the Sayanox compiler in Sayanox itself.

## Phase 4 (current)

### Codegen (`codegen.sa`)
- Walks AST parallel arrays
- Emits C: header, `main`, `printf` for `show`, assign for `hold`, `return` for `give`
- Supports expression kinds: number, ident, binary

### Pipeline (`pipeline.sa`)
- Minimal end-to-end: tokens → AST → C text

### Previous
- Phase 2: `lexer.sa`
- Phase 3: `ast.sa`, `parser.sa`

## Run

```bash
cargo build --release
./target/release/sayanox selfhost/codegen.sa -o cg.c && gcc cg.c -o cg && ./cg
./target/release/sayanox selfhost/pipeline.sa -o pipe.c && gcc pipe.c -o pipe && ./pipe
```

## Next (Phase 5)

1. Merge lexer + parser + codegen into one `.sa` compiler driver
2. Read real source strings end-to-end
3. Bootstrap: use output to compile more Sayanox

## Roadmap

| Phase | Content | Status |
|-------|---------|--------|
| 2.0 | Lexer | ✅ |
| 3.0 | AST + parser | ✅ |
| 4.0 | Codegen in Sayanox | ✅ |
| 5.0 | Unified self-host driver | 🚧 |
