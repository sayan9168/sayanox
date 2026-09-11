# Sayanox

**Sayanox** is a completely original programming language designed for simplicity and power.  
File extension: `.sa`

Created by **Sayan Mahata**.

## Philosophy
- Extremely easy and clean syntax
- Growing feature set
- Own compiler written in Rust
- Path toward native code generation (Cranelift) and full self-hosting

## Current Features (v0.3)

| Feature                        | Status          |
|--------------------------------|-----------------|
| show / hold / make / give      | ✅              |
| when / otherwise / while       | ✅              |
| Arrays + Indexing              | ✅              |
| Structs + Field access         | ✅              |
| C Code Generation              | ✅ Stable       |
| Native Backend (Cranelift)     | 🚧 Skeleton     |
| Self-hosting                   | 🚧 Phase 1      |

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

## Native Code Generation (Cranelift)

The `src/native/` module contains the foundation for a Cranelift-based backend.
Full machine-code emission and linking is the next major milestone.

## Self-Hosting (Phase 1)

See the `selfhost/` directory.

- `selfhost/README.md` – plan and minimal subset definition
- `selfhost/minimal_lexer.sa` – first experimental self-hosted frontend sketch

The long-term goal is a compiler written entirely in Sayanox that can compile itself.

## Roadmap

- [x] Lexer + Parser + AST
- [x] C Code Generation
- [x] while, Arrays, Structs
- [ ] Full Cranelift Native Backend
- [ ] Self-hosting (Phase 1 → complete)
- [ ] Standard library + package system

## License
MIT

Made with care by Sayan
