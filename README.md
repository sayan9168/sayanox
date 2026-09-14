# Sayanox

**Sayanox** - original programming language (`.sa`). By **Sayan Mahata**.

## First-party runtime

Sayanox now includes a self-contained AST runtime written with Rust's standard library. This is the foundation for reducing dependence on C/Clang and other external compiler runtimes over time.

```bash
cargo build --release
./target/release/sayanox examples/hello.sa --run
```

`--run` executes `.sa` directly through the Sayanox VM. It supports the current language subset including variables, functions, conditions, loops, arrays, strings, indexing, structs, comparisons, arithmetic, modules, and the core standard-library operations.

The long-term architecture is:

```text
.sa source
   |
   +--> lexer --> parser --> AST --> Sayanox VM       (self-contained)
   |                         |
   |                         +----> future Sayanox bytecode VM
   |
   +--> native backend (optional)
   |
   +--> C code generation (compatibility backend)
```

The C and native backends remain available while the first-party runtime grows. The goal is to make Sayanox progressively more self-hosting instead of making another language or external runtime a permanent requirement.

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

## Language (current subset)

- `show`, `hold`, `when` / `otherwise`, `while`, `make` / `give`, `struct`
- lists, strings, index, modulo `%`, assignment
- `use "file.sa"`
- stdlib: `len`, `concat`, `contains`, `starts_with`, `ends_with`, `str`, `read_file`, `write_file`, `upper`, `lower`, `trim`, `push`, `list_len`, `list_get`

## Dependency-reduction roadmap

Sayanox is being developed in layers so that external dependencies can be removed without breaking the language:

1. **First-party VM** — direct `.sa` execution without C/Clang. **Done in 0.4.0.**
2. **First-party bytecode format** — stable `.sxbc` bytecode and a Sayanox bytecode VM.
3. **First-party runtime/stdlib** — move core facilities behind a stable Sayanox runtime ABI.
4. **Self-hosting compiler** — progressively rewrite compiler components in Sayanox.
5. **First-party toolchain** — formatter, package manager, test runner, documentation generator, debugger and language server.
6. **Native code generation** — keep platform backends modular so the core compiler does not depend on one external toolchain.
7. **Bootstrap chain** — Stage-0 → Stage-1 → Stage-2 → self-hosted Sayanox compiler, with reproducible bootstrap tests.

External tools may remain as optional compatibility/back-end components, but they should not be required for ordinary Sayanox development once the first-party toolchain is mature.

## Optional: Rust host (types / export / diagnostics)

```bash
cargo build --release
./target/release/sayanox examples/modules/main.sa -o /tmp/mod --run
./target/release/sayanox examples/types_demo.sa --check
```

## License

MIT
