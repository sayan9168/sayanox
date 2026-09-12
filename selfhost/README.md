# Self-Hosting — Stage 2

## Pipeline

```text
Stage 0  Rust → compiler.sa → stage1
Stage 1  stage1 → hello_out.c + stage2_cc.c (from template)
Stage 2  stage2 hello.sa → stage2_out.c
         stage2 compiler.sa → compiler_stage2_out.c (partial)
```

## Run

```bash
./selfhost/bootstrap.sh
```

Stage 2 **opens and analyzes** full `compiler.sa` and emits a runnable report program. Full semantic re-emit of the compiler is not done yet.
