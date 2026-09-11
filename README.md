# Sayanox

**Sayanox** is a completely original programming language designed for simplicity and power.  
File extension: `.sa`

Created by **Sayan Mahata**.

## Philosophy
- Extremely easy and clean syntax
- Growing feature set
- Own compiler written in Rust
- Path toward native code generation and self-hosting

## Current Features (v0.3)

| Feature              | Status |
|----------------------|--------|
| show (print)         | ✅     |
| hold (variables)     | ✅     |
| make / give (functions) | ✅  |
| when / otherwise     | ✅     |
| while loops          | ✅     |
| Arrays `[1, 2, 3]` + indexing | ✅ |
| Structs              | ✅     |
| Field access `p.x`   | ✅     |
| C Code Generation    | ✅     |
| Native (Cranelift)   | 🚧 Skeleton |
| Self-hosting         | 🚧 Planned |

## Example

```sa
show "Hello from Sayanox!"

make double(n) {
    give n * 2
}

hold nums = [10, 20, 30]
show nums[1]

make struct Point {
    x, y
}

hold p = Point { x: 5, y: 15 }
show p.x
```

## Build & Run

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
cargo build --release

./target/release/sayanox examples/hello.sa -o hello.c
gcc hello.c -o hello
./hello
```

## Roadmap

- [x] Lexer + Parser + AST
- [x] C Code Generation
- [x] while loops
- [x] Arrays + Indexing
- [x] Structs + Field access
- [ ] Full Native Code Generation (Cranelift)
- [ ] Self-hosting compiler
- [ ] Better type system & memory model
- [ ] Standard library

## Native Code Generation (Cranelift)

A foundation is ready for Cranelift integration.  
Next major milestone is emitting machine code directly instead of C.

## Self-hosting

Plan:
1. Keep the Rust bootstrap compiler stable.
2. Implement a minimal subset of Sayanox that can express the compiler.
3. Rewrite the frontend in Sayanox itself.
4. Achieve full self-hosting.

## License
MIT

Made with care by Sayan
