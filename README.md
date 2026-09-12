# Sayanox

**Sayanox** is an original programming language using `.sa` source files.

## Version

**0.3.28**

## Quick start

```bash
cargo run -- examples/hello.sa -o hello.c
clang hello.c -o hello
./hello
```

Or use the bundled Stage-2 CLI:

```bash
chmod +x selfhost/sx
./selfhost/sx examples/hello.sa --run
```

The current default compiler pipeline is:

```text
.sa -> lexer -> parser -> AST -> C code -> clang/gcc -> native executable
```

The repository also contains an experimental Cranelift JIT/AOT backend behind the `native` feature.

## Language basics

```sayanox
show "Hello, Sayanox!"

hold name = "Sayan"
hold count = 3
show concat("Hello ", name)

when count > 0 {
    show "ready"
}

make double(n) {
    give n * 2
}

show double(21)
```

Assignments use `name = value` after a value has been declared:

```sayanox
hold i = 1
while i <= 3 {
    show i
    i = i + 1
}
```

## Small standard library

Sayanox keeps its initial standard library intentionally small and useful:

| Helper | Purpose |
| --- | --- |
| `len(value)` | String or list length |
| `concat(a, b)` | Join two strings |
| `contains(text, part)` | String containment; returns `1` or `0` |
| `starts_with(text, prefix)` | Prefix check; returns `1` or `0` |
| `ends_with(text, suffix)` | Suffix check; returns `1` or `0` |
| `upper(text)` | Uppercase string |
| `lower(text)` | Lowercase string |
| `trim(text)` | Trim surrounding whitespace |
| `push(list, value)` | Append a number to a list |
| `list_len(list)` | List length |
| `list_get(list, index)` | Read a list element |
| `str(number)` | Number to string |
| `read_file(path)` | Read a file as text |
| `write_file(path, text)` | Write text to a file |

Example:

```sayanox
hold raw = "  Sayanox  "
hold clean = trim(raw)
show upper(clean)
show contains(clean, "yan")

hold numbers = [10, 20, 30]
push(numbers, 40)
show list_len(numbers)
show list_get(numbers, 2)
```

## Diagnostics

Compiler errors now include:

- error phase (`lexer` or `parser`)
- source file, line, and column
- a small source snippet
- a caret pointing at the reported location
- a contextual hint when the error is recognizable

This is intentionally dependency-free and is designed to make first-time compiler errors easier to understand.

## Examples

- `examples/hello.sa` — language tour: functions, assignment, loops, lists, and structs.
- `examples/stdlib.sa` — string and list standard-library helpers.
- `examples/errors/` — intentionally invalid programs used to demonstrate diagnostics.

## Repository layout

```text
src/
  lexer.rs       Tokenization and source locations
  parser.rs      Recursive-descent parser
  ast.rs         Abstract syntax tree
  stdlib.rs      Built-in library registry
  diagnostic.rs  User-facing error rendering
  codegen.rs     C backend and runtime library
  native/        Experimental Cranelift backend
selfhost/        Stage-2 and bootstrap tooling
examples/        Beginner-friendly language examples
```

## Development

```bash
cargo fmt --check
cargo test
cargo build
```

Keep language behavior documented in examples before adding syntax that changes the grammar.

## License

MIT
