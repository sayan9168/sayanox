# Sayanox

**Sayanox** is a completely original programming language designed for simplicity and power.  
File extension: `.sa`

Created by **Sayan Mahata**.

## Current Features (v0.3.15)

| Feature | Status |
|---------|--------|
| Core language + C backend | ✅ |
| Full AOT (Cranelift) | ✅ |
| Self-host Phases 2–6 | ✅ |
| **Phase 7 disk bootstrap pipeline** | ✅ |

## Build

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
cargo build --release
```

### Phase 7 (self-host from disk)

```bash
./target/release/sayanox selfhost/compiler.sa -o boot.c
gcc boot.c -o boot && ./boot
gcc selfhost/hello_out.c -o hello_out && ./hello_out
```

## License

MIT
