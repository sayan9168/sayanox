# Sayanox

**Sayanox** is a completely original programming language designed for simplicity and power.  
File extension: `.sa`

Created by **Sayan Mahata**.

## Current Features (v0.3.17)

| Feature | Status |
|---------|--------|
| Core language + C backend | Yes |
| Full AOT (Cranelift) | Yes (limited) |
| File I/O, `str`, `concat`, `push` | Yes |
| **Stage-1 self-host binary** | Yes |
| Stage-2 (stage1 compiles `compiler.sa`) | In progress |

## Build

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
cargo build --release
```

## Bootstrap (Stage 0 → Stage 1)

```bash
./selfhost/bootstrap.sh
```

This builds a **Sayanox-built** `selfhost/stage1` binary that compiles `selfhost/hello.sa` from disk.

## License

MIT
