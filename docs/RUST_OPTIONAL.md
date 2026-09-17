# Rust is optional

**You do not need Rust or Cargo to use Sayanox.**

## Primary toolchain (no Rust)

```bash
./selfhost/restore_stage2.sh
./selfhost/sx examples/hello.sa --run
```

Requires: `bash`, `curl`, `clang` or `gcc`.

## Optional Rust host

- **Dependencies:** none (Rust `std` only)
- **Cranelift / native crates:** removed
- Build only if you want the secondary VM / C-emit host:

```bash
cargo build --release
./target/release/sayanox examples/hello.sa --run
```

For real native binaries prefer Stage-2 → C → `clang`, not the Rust host.
