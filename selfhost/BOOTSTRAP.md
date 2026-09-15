# Bootstrap (B)

```text
restore_stage2.sh  →  stage2 binary (.sa → C)
        ↓
   ./selfhost/sx file.sa --run     ← daily use, no Rust
        ↓
   codegen.sa (optional)           ← compiler logic in Sayanox
```

Rust host is optional (richer types, `--native` Cranelift).

```bash
./selfhost/restore_stage2.sh
./selfhost/sx examples/hello.sa --run
```
