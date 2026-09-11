# Sayanox

**Sayanox** is a completely original programming language designed for simplicity and power.  
File extension: `.sa`

Created by **Sayan Mahata**.

## Current Features (v0.3.3)

| Feature                        | Status                  |
|--------------------------------|-------------------------|
| show / hold / make / give      | ✅                      |
| when / otherwise / while       | ✅                      |
| Arrays + Indexing              | ✅                      |
| Structs + Field access         | ✅                      |
| C Code Generation              | ✅ Stable               |
| Native (Cranelift)             | 🚧 Feature-gated start  |
| Self-hosting                   | 🚧 Phase 1.1            |

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

## Self-Hosting

See `selfhost/` directory. The minimal lexer is written in pure Sayanox and is becoming more realistic.

## License
MIT
