# Stage 2 — Full semantic compile of `compiler.sa`

When Stage 2 compiles `selfhost/compiler.sa`, it emits **working C** that
re-implements the Stage-1 compiler (read hello.sa, write hello_out.c, emit stage2).

```bash
./selfhost/bootstrap.sh
```

Semantic equivalence for Stage-1 behavior; generic full-language lowering is future work.
