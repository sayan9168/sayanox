# Sayanox

**Sayanox** — original language (`.sa`). By **Sayan Mahata**.

## v0.3.21

| Feature | Status |
|---------|--------|
| Core + C backend | Yes |
| Stage 0 / 1 bootstrap | Yes |
| **Stage 2 generic lowering** | Yes |
| Stage 2 supports | `show` `hold` `when`/`otherwise` `while` exprs |
| Stage 2 semantic `compiler.sa` | Yes |
| Full `make` body lowering | Partial (skipped with comment) |

## Bootstrap

```bash
cargo build --release
./selfhost/bootstrap.sh
```

## Generic Stage-2 example

```bash
gcc -o selfhost/stage2 selfhost/stage2_template.c
./selfhost/stage2 selfhost/generic_demo.sa out.c
gcc out.c -o out && ./out
```

## License

MIT
