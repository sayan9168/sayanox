# Self-hosting

## Supported bootstrap paths

Build Stage-2 directly:

```bash
make stage2
```

Or use the supported shell bootstrap:

```bash
./selfhost/restore_stage2.sh
```

For the production codegen smoke path:

```bash
./selfhost/bootstrap_production.sh
```

For the full compiler bootstrap paths:

```bash
./selfhost/bootstrap_full_selfhost.sh
./selfhost/bootstrap_full_language_selfhost.sh
```

After Stage-2 is available, normal `.sa` compilation uses:

```bash
./selfhost/sx any_file.sa --run
```

## Supported compiler boundary

| Layer | Role |
|-------|------|
| `build_stage2.c` / `restore_stage2.sh` | Builds the Stage-2 compiler |
| `sx` | CLI over Stage-2 for normal `.sa` compilation |
| `codegen.sa` | Sayanox-written code generation path |
| `bootstrap_production.sh` | Supported production smoke/bootstrap path |

Numbered `stage*.sh` and `step*.sh` scripts are retired and are not part of the supported self-hosting workflow.
