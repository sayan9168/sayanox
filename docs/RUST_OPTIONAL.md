# Rust removed

The optional Rust host (`Cargo.toml`, `src/`) has been **removed**.

Use only:

```bash
./selfhost/restore_stage2.sh
./selfhost/sx examples/hello.sa --run
```

Requirements: `bash`, `curl`, `clang`/`gcc`.
