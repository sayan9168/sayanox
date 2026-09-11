# Sayanox

**Sayanox** is a completely original programming language designed for simplicity and power.  
File extension: `.sa`

Created by **Sayan Mahata**.

## Current Features (v0.3.4)

| Feature                        | Status                     |
|--------------------------------|----------------------------|
| show / hold / make / give      | ✅                         |
| when / otherwise / while       | ✅                         |
| Arrays + Indexing              | ✅                         |
| Structs + Field access         | ✅                         |
| C Code Generation              | ✅ Stable                  |
| Native Backend (Cranelift)     | 🚧 Feature-gated + JIT demo|
| Self-hosting                   | 🚧 Phase 1.2               |

## Build

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
cargo build --release
```

### Experimental Native / JIT

```bash
cargo build --features native --release
./target/release/sayanox examples/hello.sa --jit
```

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

## Native Code Generation (Cranelift)

The `src/native/` module contains a real (feature-gated) Cranelift integration.
A minimal JIT path is already present and will be expanded to full expression lowering.

## Self-Hosting

See the `selfhost/` directory.

- Phase 1.2 minimal lexer is written in pure Sayanox
- Clear list of language features still needed for a complete scanner

## License

MIT
