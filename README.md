# Sayanox

**Sayanox** — original language (`.sa`). By **Sayan Mahata**.

## v0.3.23 — Phase A (self-host loop)

```bash
cargo build --release
./selfhost/bootstrap_stage3.sh
```

This builds Stage-2, **generically** compiles `compiler_boot.sa` → Stage-3 binary,
then Stage-3 compiles `hello.sa` (proof of self-host loop without Rust for that step).

## License

MIT
