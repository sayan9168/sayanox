# Sayanox

**Sayanox** is a completely original programming language designed for simplicity and power.  
File extension: `.sa`

Created by **Sayan Mahata**.

## Current Features (v0.3.7 — Phase A complete)

| Feature                        | Status |
|--------------------------------|--------|
| Core language + C backend      | ✅     |
| Arrays, Structs, while         | ✅     |
| String indexing (char codes)   | ✅     |
| `len(string)` / `len(list)`    | ✅     |
| Dynamic list `push`            | ✅ New |
| String `concat`                | ✅ New |
| Improved error messages        | ✅ New |
| Cranelift native (expr JIT)    | 🚧     |
| Self-hosting                   | 🚧 Phase 1.5 |

## Build

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
cargo build --release
./target/release/sayanox examples/phase_a.sa -o out.c
gcc out.c -o out && ./out
```

## Phase A Example

```sa
hold xs = []
push(xs, 10)
push(xs, 20)
show len(xs)
show xs[0]

hold msg = concat("Hello, ", "Sayanox!")
show msg
```

## License

MIT
