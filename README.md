# Sayanox

**Sayanox** is a completely original programming language designed for simplicity and power.  
File extension: `.sa`

Created by **Sayan Mahata**.

## Current Features (v0.3.16)

| Feature | Status |
|---------|--------|
| Core language + C backend | ✅ |
| Full AOT (Cranelift) | ✅ |
| Self-host pipeline | ✅ |
| `str(number)` number→string | ✅ New |
| Disk bootstrap (`bootstrap.sh`) | ✅ |

## Build

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
cargo build --release
```

### Number to string

```bash
./target/release/sayanox examples/str_demo.sa -o s.c && gcc s.c -o s && ./s
```

### Bootstrap

```bash
./selfhost/bootstrap.sh
```

## License

MIT
