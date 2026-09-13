# Sayanox

**Sayanox** - original language (`.sa`). By **Sayan Mahata**.

## Self-host (complete)

You do **not** need Rust to compile `.sa` files after Stage-2 is built once.

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox

# One command - builds Stage-2 and verifies the full self-host loop
make selfhost
# or: ./selfhost/bootstrap_selfhost.sh
```

Expect: `=== DEEP SELF-HOST COMPLETE ===`

### Compile any program

```bash
./selfhost/sx examples/hello.sa --run
./selfhost/sx selfhost/modules/main.sa -o /tmp/mod --run
./selfhost/sx your_file.sa --run
```

`sx` auto-prepares Stage-2 the first time.

### Pipeline

```text
restore_stage2.sh  ->  complete Stage-2 (.sa -> C compiler)
       |
       +--> stage2 binary  -->  any .sa  -->  C  -->  native binary
       |
       +--> CLI: ./selfhost/sx file.sa [--run]
       |
       +--> Stage-3: compiler_boot.sa (Sayanox program emits C)
```

### Optional: Rust host (types / export / diagnostics)

```bash
cargo build --release
./target/release/sayanox examples/modules/main.sa -o /tmp/m.c
./target/release/sayanox examples/types_demo.sa --check
```

## Language (subset for Stage-2)

- `show`, `hold`, `when` / `otherwise`, `while`, `make` / `give`, `struct`
- lists, strings, index, modulo `%`, assignment
- `use "file.sa"`
- stdlib: `len`, `concat`, `str`, `read_file`, `write_file`, `upper`, `lower`, `trim`, ...

## License

MIT
