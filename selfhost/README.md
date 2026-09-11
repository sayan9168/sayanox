# Self-Hosting Sayanox — Phase 7

## True bootstrap path

```
selfhost/hello.sa  --read_file-->  lex → AST → C  --write_file-->  selfhost/hello_out.c
```

Still executed by the **Rust bootstrap** compiler (`sayanox`), but the **compiler logic and file I/O** are written in pure Sayanox.

## Files

| File | Role |
|------|------|
| `hello.sa` | Tiny input program (`show 42`) |
| `compiler.sa` | Phase 7 driver (read → compile → write) |
| `hello_out.c` | Produced after running the driver |

## Run

```bash
cargo build --release
./target/release/sayanox selfhost/compiler.sa -o boot.c
gcc boot.c -o boot && ./boot
# then:
gcc selfhost/hello_out.c -o hello_out && ./hello_out
```

## What Phase 7 proves

1. `read_file` loads a real `.sa` from disk  
2. Self-hosted lexer/parser/codegen run on that source  
3. `write_file` emits a `.c` file  
4. That `.c` can be compiled with `gcc` and run  

## Still not full self-host

- The **driver** is still compiled by the Rust `sayanox` binary  
- Full self-host = use a Sayanox-built binary to compile `compiler.sa` itself  
- Needs richer codegen (numbers → strings, full grammar)

## Roadmap

| Phase | Status |
|-------|--------|
| 6 File I/O | ✅ |
| 7 Disk end-to-end pipeline | ✅ |
| 8 Compile compiler.sa with its own output (bootstrap loop) | 🚧 |
