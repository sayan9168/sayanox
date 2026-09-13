# Sayanox

**Sayanox** — original language (`.sa`). By **Sayan Mahata**.

## v0.3.30

| Feature | Status |
| --- | --- |
| Modules (`use "file.sa"`) | Yes |
| Light type checker | Yes (`--check`) |
| Cranelift AOT | Stronger link path (`--features native`) |
| Package manager | `tools/sxpkg` |

## Quick start

```bash
cargo build --release
./target/release/sayanox examples/hello.sa -o hello.c
clang hello.c -o hello && ./hello

# Multi-file
./target/release/sayanox examples/modules/main.sa -o /tmp/mod.c

# Type check
./target/release/sayanox examples/types_demo.sa --check

# Stage-2 CLI (no Rust needed at runtime)
./selfhost/sx selfhost/hello.sa --run
```

## Modules

```sayanox
use "math.sa"
hold x = double(21)
show x
```

## Package manager

```bash
chmod +x tools/sxpkg
./tools/sxpkg init
# edit Sayanox.toml [deps]
./tools/sxpkg install
./tools/sxpkg list
```

## Native AOT (Cranelift)

```bash
cargo build --release --features native
./target/release/sayanox examples/hello.sa --native -o hello_aot
./hello_aot
```

## License

MIT
