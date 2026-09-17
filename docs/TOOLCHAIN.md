# Toolchain (no Bash core)

```
make stage2   # C: build_stage2.c → stage2
make sx       # Sayanox: sx.sa → sx_bin
./selfhost/sx_bin file.sa out 1
```

Builtins in Stage-2 for tooling: `run`, `arg`, `arg_count`.
