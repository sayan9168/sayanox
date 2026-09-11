# Sayanox

**Sayanox** is a completely original programming language designed for simplicity and power.  
File extension: `.sa`

Created by **Sayan Mahata**.

## Current Features (v0.3.12)

| Feature | Status |
|---------|--------|
| Core language + C backend | ✅ |
| Full AOT (Cranelift) | ✅ |
| Self-hosted lexer | ✅ |
| Self-hosted AST + parser | ✅ |
| Self-hosted codegen | ✅ Phase 4 |

## Build

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
cargo build --release
```

### Self-hosting Phase 4

```bash
./target/release/sayanox selfhost/codegen.sa -o cg.c && gcc cg.c -o cg && ./cg
./target/release/sayanox selfhost/pipeline.sa -o pipe.c && gcc pipe.c -o pipe && ./pipe
```

## License

MIT
