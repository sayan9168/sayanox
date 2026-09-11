# Sayanox

**Sayanox** is a completely original programming language designed for simplicity and power.  
File extension: `.sa`

Created by **Sayan Mahata**.

## Current Features (v0.3.9)

| Feature | Status |
|---------|--------|
| Core language + C backend | ✅ |
| Dynamic `push`, `concat`, `len` | ✅ |
| Cranelift expression / control-flow | ✅ |
| **Full AOT** (object + link → binary) | ✅ New |
| Self-hosting | 🚧 |

## Build

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
cargo build --release
```

### C backend (default)

```bash
./target/release/sayanox examples/phase_a.sa -o out.c
gcc out.c -o out && ./out
```

### Full AOT native binary

```bash
cargo build --features native --release
./target/release/sayanox examples/phase_b.sa --native -o myprog
./myprog
echo $?   # exit code is the computed numeric result
```

### JIT

```bash
./target/release/sayanox examples/phase_b.sa --jit
```

## License

MIT
