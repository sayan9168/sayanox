# Sayanox

**Sayanox** is a completely original programming language designed for simplicity and power.  
File extension: `.sa`

Created by **Sayan Mahata**.

## Current Features (v0.3.18)

| Feature | Status |
|---------|--------|
| Core language + C backend | Yes |
| Stage-1 self-host binary | Yes |
| **Stage-2 mini compiler (emitted by Stage 1)** | Yes |
| Stage-2 compiles full `compiler.sa` | Not yet |

## Bootstrap (Stage 0 → 1 → 2)

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
cargo build --release
./selfhost/bootstrap.sh
```

## License

MIT
