# Sayanox

**Sayanox** is a completely original programming language designed for simplicity and power.  
File extension: `.sa`

Created by **Sayan Mahata**.

## Current Features (v0.3.10)

| Feature | Status |
|---------|--------|
| Core language + C backend | ✅ |
| Dynamic `push`, `concat`, `len` | ✅ |
| Full AOT (Cranelift + cc) | ✅ |
| Self-hosted lexer (char-by-char) | 🚧 Phase 2.0 |
| Self-hosted parser sketch | 🚧 Phase 2.0 |

## Build

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
cargo build --release
```

### Self-hosting Phase 2.0

```bash
./target/release/sayanox selfhost/lexer.sa -o lexer.c
gcc lexer.c -o lexer && ./lexer

./target/release/sayanox selfhost/parser.sa -o parser.c
gcc parser.c -o parser && ./parser
```

### Full AOT

```bash
cargo build --features native --release
./target/release/sayanox examples/aot_demo.sa --native -o myprog
./myprog
```

## License

MIT
