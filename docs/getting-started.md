# Getting Started with Sayanox

Sayanox is an original programming language with `.sa` source files. This guide is for a first-time user.

## 1. Build the compiler

Install Rust and a C compiler such as Clang or GCC, then run:

```bash
cargo build --release
```

## 2. Run your first program

Create `hello.sa`:

```sayanox
show "Hello from Sayanox!"
```

Compile it to C:

```bash
cargo run -- hello.sa -o hello.c
```

Build the executable:

```bash
clang hello.c -o hello
./hello
```

The bundled helper can do the Stage-2 compile-and-run flow:

```bash
./selfhost/sx hello.sa --run
```

## 3. Values and variables

Use `hold` to create a value:

```sayanox
hold name = "Sayan"
hold age = 17
show name
show age
```

Use assignment when you need to change an existing numeric variable:

```sayanox
hold count = 0
count = count + 1
show count
```

## 4. Functions

```sayanox
make square(n) {
    give n * n
}

show square(8)
```

## 5. Conditions and loops

```sayanox
hold n = 3

when n > 0 {
    show "positive"
} otherwise {
    show "not positive"
}

hold i = 1
while i <= 3 {
    show i
    i = i + 1
}
```

## 6. Lists

Lists contain numeric values in the current compiler:

```sayanox
hold values = [10, 20, 30]
push(values, 40)
show list_len(values)
show list_get(values, 1)
```

## 7. Strings

```sayanox
hold text = trim("  hello  ")
show upper(text)
show contains(text, "ell")
show concat(text, " world")
```

## 8. Errors

When the lexer or parser rejects a program, Sayanox reports the phase, source location, nearby lines, a caret, and a hint when possible.

Try the intentionally invalid example:

```bash
cargo run -- examples/errors/missing_paren.sa
```

Fix the highlighted line, then run the compiler again.

## 9. Learn by example

Start with:

- `examples/hello.sa`
- `examples/stdlib.sa`
- `examples/errors/missing_paren.sa`

For the current language implementation, read `src/lexer.rs`, `src/parser.rs`, `src/ast.rs`, and `src/codegen.rs` together. The parser defines what source syntax is accepted and the code generator defines the current executable behavior.
