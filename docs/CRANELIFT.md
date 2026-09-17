# Cranelift status

Cranelift integration was **removed** to eliminate heavy optional crates.

Native executables:

```bash
./selfhost/sx program.sa -o program --run
```

Stage-2 emits C; `clang`/`gcc` produces the binary.
