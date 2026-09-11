# Sayanox

**Sayanox** is a completely original programming language designed for simplicity and power.  
File extension: `.sa`

Created by **Sayan Mahata**.

## Current Features (v0.3.11)

| Feature | Status |
|---------|--------|
| Core language + C backend | ✅ |
| Dynamic push / concat / len | ✅ |
| Full AOT (Cranelift) | ✅ |
| Self-hosted lexer | ✅ Phase 2 |
| Self-hosted AST + parser | ✅ Phase 3 |

## Build

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
cargo build --release
```

### Self-hosting Phase 3

```bash
./target/release/sayanox selfhost/ast.sa -o ast.c && gcc ast.c -o ast && ./ast
./target/release/sayanox selfhost/parser.sa -o parser.c && gcc parser.c -o parser && ./parser
```

## License

MIT
