# Sayanox

**Sayanox** is a completely original programming language designed for simplicity and power.  
File extension: `.sa`

Created by **Sayan Mahata**.

## Current Features (v0.3.8)

| Feature | Status |
|---------|--------|
| Core language + C backend | ✅ |
| Dynamic `push`, `concat`, `len` | ✅ Phase A |
| Cranelift expression lowering | ✅ |
| Function call lowering (structure) | 🚧 Phase B |
| Control flow lowering (when/while) | 🚧 Phase B |
| Simple program eval via `--jit` | ✅ Phase B |
| Full AOT object + link | 🚧 Next |

## Build

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
cargo build --release
./target/release/sayanox examples/phase_a.sa -o out.c && gcc out.c -o out && ./out
```

### Native / JIT (Phase B)

```bash
cargo build --features native --release
./target/release/sayanox examples/phase_b.sa --jit
```

## License

MIT
