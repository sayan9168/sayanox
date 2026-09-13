# Sayanox

**Sayanox** — original language (`.sa`). By **Sayan Mahata**.

## v0.3.31

- **Diagnostics**: snippet + caret on lexer/parser paths; richer hints
- **Deeper types**: arity checks, struct fields, `give` scope, when/while conditions
- **Modules**: `use "file.sa"` + `export make` / `export hold` / `export struct`

```bash
cargo build --release
./target/release/sayanox examples/modules/main.sa -o /tmp/m.c && clang /tmp/m.c -o /tmp/m && /tmp/m
./target/release/sayanox examples/types_demo.sa --check
cargo test
```

### Export example

```sayanox
// math.sa
export make double(n) { give n * 2 }

// main.sa
use "math.sa"
show double(21)
```

## License

MIT
