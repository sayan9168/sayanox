# Sayanox Language Tutorial

Sayanox is a general-purpose programming language with `.sa` source files. The compiler is being self-hosted: the supported bootstrap keeps a tiny Stage-2 host while progressively moving parsing, semantic analysis, lowering, and code generation into Sayanox.

## 1. Hello world

```sa
show "Hello, Sayanox!"
```

Run it with:

```sh
make stage2
./selfhost/sx examples/hello.sa --run
```

## 2. Variables

Use `hold` for a local binding.

```sa
hold name = "Sayan"
hold year = 2026
show name
show year
```

## 3. Conditions

```sa
hold age = 18
when age >= 18 {
  show "adult"
} otherwise {
  show "minor"
}
```

## 4. Loops

```sa
hold n = 1
while n <= 5 {
  show n
  hold n = n + 1
}
```

## 5. Functions

```sa
make add(a, b) {
  give a + b
}

hold result = add(20, 22)
show result
```

## 6. Strings

The standard library exposes string helpers such as `len`, `concat`, `char_at`, `char_code`, `contains`, `starts_with`, `ends_with`, `upper`, `lower`, `trim`, and `str`.

```sa
hold first = "Sayan"
hold last = "ox"
show concat(first, last)
show upper(first)
show len(first)
```

## 7. Lists

Lists use square brackets. Indexing is zero-based.

```sa
hold numbers = [10, 20, 30]
push(numbers, 40)
show numbers[1]
show len(numbers)
```

## 8. File I/O

```sa
hold text = read_file("input.txt")
hold status = write_file("output.txt", text)
show status
```

## 9. Building larger programs

Prefer small functions, explicit locals, and clear names. Keep I/O at program boundaries and keep transformation logic in functions so it can later be lowered to the Sayanox IR without backend-specific assumptions.

## 10. Self-hosting model

The bootstrap currently has this shape:

```text
Tiny C Stage-2 bootstrap
        |
        v
Sayanox compiler sources
        |
        v
Sayanox-owned AST / semantic / IR / lowering
        |
        v
Backend
```

The final C-free bootstrap requires a native backend. Until that exists, claims of complete C/Clang independence would be incorrect.

## 11. From beginner to advanced

After the basics, read:

1. `docs/SYNTAX.md` for the syntax reference.
2. `docs/BOOTSTRAP_ROADMAP.md` for the self-hosting plan.
3. `selfhost/SELFHOST.md` for the current bootstrap path.
4. `docs/LSP.md` for editor integration.
5. `tools/sxpkg` for local package management.

Then study the compiler sources in this order:

```text
lexer -> parser -> AST -> semantic analysis -> checked AST -> IR -> lowering -> backend
```
