# Sayanox 🚀

**Sayanox** is a completely original programming language designed for simplicity and power.  
File extension: **`.sa`**

Created by **Sayan Mahata**.

## Philosophy
- Extremely easy and clean syntax
- Many features (growing)
- Own compiler written in Rust
- No unnecessary complexity

## Current Features (v0.1)
- `show` – print anything
- `hold` – declare variables (numbers & strings)
- `make` – define functions
- `give` – return from function
- `when` / `otherwise` – conditionals
- Basic arithmetic: `+ - * /`
- Comparison: `> < == != >= <=`
- Comments with `//`

## Example

```sa
// hello.sa
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

hold result = double(21)
show result
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
```

This will generate `hello.c`. Then compile it with GCC:

```bash
gcc hello.c -o hello
./hello
```

## Roadmap
- [x] Lexer
- [x] Parser
- [x] AST
- [x] C Code Generation (transpiler)
- [ ] Native code generation (Cranelift / LLVM)
- [ ] Self-hosting compiler (rewrite in Sayanox)
- [ ] More types, arrays, structs
- [ ] Standard library
- [ ] Package manager

## License
MIT

Made with ❤️ by Sayan
