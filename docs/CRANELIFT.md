# Cranelift native backend (C)

```bash
cargo build --release --features native
./target/release/sayanox examples/hello.sa --jit
./target/release/sayanox examples/hello.sa --native -o /tmp/hello
```

Feature flag: `native` in `Cargo.toml` (cranelift-codegen, object, …).

MVP: arithmetic / control flow lowering; not full stdlib parity with C backend.
