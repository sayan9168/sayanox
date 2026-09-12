# Sayanox

**Sayanox** — original language (`.sa`). By **Sayan Mahata**.

## v0.3.22

Stage-2 generic lowering now includes:

- `make` function body → C functions
- Runtime: `read_file` `write_file` `push` `concat` `str` `len`
- Arrays: `[]`, `[1,2,3]`, `a[i]`
- `show` `hold` `when` `while` expressions

```bash
cargo build --release
./selfhost/bootstrap.sh
gcc -o selfhost/stage2 selfhost/stage2_template.c
./selfhost/stage2 selfhost/generic_demo.sa out.c && gcc out.c -o out && ./out
```

## License

MIT
