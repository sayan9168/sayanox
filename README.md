# Sayanox

**Sayanox** is a completely original programming language designed for simplicity and power.  
File extension: `.sa`

Created by **Sayan Mahata**.

## Current Features (v0.3.6)

| Feature                        | Status                            |
|--------------------------------|-----------------------------------|
| show / hold / make / give      | ✅                                |
| when / otherwise / while       | ✅                                |
| Arrays + Indexing              | ✅                                |
| Structs + Field access         | ✅                                |
| String indexing → char code    | ✅                                |
| len(string) / len(array)       | ✅ New                            |
| C Code Generation              | ✅ Stable                         |
| Native Backend (Cranelift)     | 🚧 Full expression tree lowering  |
| Self-hosting                   | 🚧 Phase 1.4                      |

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
hold s = "hello"
show s[0]           // char code of 'h'
show len(s)         // 5

hold nums = [10, 20, 30]
show len(nums)      // 3
show nums[1]
```

## Native (Cranelift)

Full recursive expression tree lowering for arithmetic is implemented.
The JIT path can evaluate constant numeric expressions via real machine code.

## Self-Hosting

See `selfhost/`. Phase 1.4 lexer uses string indexing + `len()`.

## License

MIT
