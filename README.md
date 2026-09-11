# Sayanox

**Sayanox** is a completely original programming language designed for simplicity and power.  
File extension: `.sa`

Created by **Sayan Mahata**.

## Current Features (v0.3.5)

| Feature                        | Status                          |
|--------------------------------|---------------------------------|
| show / hold / make / give      | ✅                              |
| when / otherwise / while       | ✅                              |
| Arrays + Indexing              | ✅                              |
| Structs + Field access         | ✅                              |
| String indexing → char code    | ✅ New                          |
| C Code Generation              | ✅ Stable                       |
| Native Backend (Cranelift)     | 🚧 Arithmetic + JIT path        |
| Self-hosting                   | 🚧 Phase 1.3                    |

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

hold s = "hello"
show s[0]          // character code of 'h'

make double(n) {
    give n * 2
}

hold nums = [10, 20, 30]
show nums[1]
```

## Native (Cranelift)

Real Cranelift JIT pipeline is present (feature-gated).  
Arithmetic operators can be lowered to Cranelift IR; full AOT is next.

## Self-Hosting

See `selfhost/`. Phase 1.3 lexer now uses string indexing for character codes.

## License

MIT
