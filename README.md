# Sayanox 🚀

**Sayanox** is a completely original programming language with easy syntax and its own compiler written in Rust.  
File extension: **`.sa`**

Created by **Sayan Mahata**.

## Philosophy
- Extremely easy and clean syntax
- Many features (growing fast)
- Own compiler written in Rust
- No unnecessary complexity

## Current Features (v0.2)
- `show` – print numbers & strings
- `hold` – declare variables
- `make` – define functions
- `give` – return from function
- `when` / `otherwise` – conditionals
- `while` – loops
- Arithmetic: `+ - * /`
- Comparison: `> < == != >= <=`
- Comments with `//`

## Example

```sa
show "Hello from Sayanox!"

hold x = 42

make double(n) {
    give n * 2
}

show double(x)

when x > 10 {
    show "Big number"
} otherwise {
    show "Small number"
}

hold i = 1
while i <= 5 {
    show i
    hold i = i + 1
}
```

## How to use

### 1. Install Rust
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### 2. Build the compiler
```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
cargo build --release
```

### 3. Compile a Sayanox program
```bash
./target/release/sayanox examples/hello.sa -o hello.c
gcc hello.c -o hello
./hello
```

## Roadmap
- [x] Lexer + Parser + AST
- [x] C Code Generation
- [x] while loops
- [ ] Native code generation (Cranelift)
- [ ] Self-hosting compiler
- [ ] Arrays, structs, better type system
- [ ] Standard library

## License
MIT

Made with ❤️ by Sayan
