# Sayanox

**Sayanox** is a completely original programming language designed for simplicity and power.  
File extension: `.sa`

Created by **Sayan Mahata**.

## Current Features (v0.3.14)

| Feature | Status |
|---------|--------|
| Core language + C backend | ✅ |
| Full AOT (Cranelift) | ✅ |
| Self-host pipeline (Phases 2–5) | ✅ |
| **File I/O builtins** | ✅ Phase 6 |
| `read_file` / `write_file` | ✅ |

## Build

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
cargo build --release
```

### File I/O

```bash
./target/release/sayanox examples/file_io.sa -o fio.c
gcc fio.c -o fio && ./fio
```

## License

MIT
