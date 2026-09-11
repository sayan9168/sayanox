# Sayanox

**Sayanox** is a completely original programming language designed for simplicity and power.  
File extension: `.sa`

Created by **Sayan Mahata**.

## Current Features (v0.3.13)

| Feature | Status |
|---------|--------|
| Core language + C backend | ✅ |
| Full AOT (Cranelift) | ✅ |
| Self-hosted lexer / parser / AST / codegen | ✅ |
| **Unified self-host compiler driver** | ✅ Phase 5 |

## Build

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
cargo build --release
```

### Self-hosted compiler (Phase 5)

```bash
./target/release/sayanox selfhost/compiler.sa -o compiler.c
gcc compiler.c -o compiler && ./compiler
```

## License

MIT
