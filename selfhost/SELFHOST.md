# Deep self-host (done)

## One command

```bash
./selfhost/bootstrap_selfhost.sh
```

This will:
1. Download + complete Stage-2 template (English, use, modulo)
2. Build `selfhost/stage2`
3. Prove hello, sx CLI, modules, Stage-3, compiler.sa path

After that, **only** use:

```bash
./selfhost/sx any_file.sa --run
```

No further manual steps required for normal compiling.

## What is self-hosted

| Layer | Role |
|-------|------|
| Stage-2 (`stage2_template.c` completed) | Production `.sa` -> C compiler |
| `sx` | CLI over Stage-2 for any path |
| Stage-3 (`compiler_boot.sa`) | Sayanox program that emits C |
| `compiler.sa` | Stage-1 style self-host driver |

Rust host is optional (richer types / export / errors).
