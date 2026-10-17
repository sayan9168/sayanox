# Self-hosting

> **The entry points named in this file do not exist (verified 2026-10-13).**
> There is no `make stage2` target, and no `selfhost/bootstrap_production.sh`,
> `bootstrap_full_selfhost.sh` or `bootstrap_full_language_selfhost.sh`.
> `selfhost/stage2_template.c` is a 93-byte placeholder, `selfhost/stage2_src/`
> holds a README and an 11-byte placeholder, `selfhost/sxc_full.c` is a 30-line
> toy, and `bash selfhost/restore_stage2.sh` exits 1 with
> `error: missing Stage-2 seed`. The supported path is
> `make doctor && make true-selfhost && make gen3 && make native-test`;
> `docs/FULL_LANGUAGE_SELFHOST.md` says what actually runs and
> `make test-doc-claims` keeps this banner honest.

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
| `restore_stage2.sh` | Attempts the (absent) Stage-2 host; exits 1 today |
| `sx` | CLI over Stage-2 for normal `.sa` compilation |
| `codegen.sa` | Sayanox-written code generation path |
| `bootstrap_production.sh` | Supported production smoke/bootstrap path |

Numbered `stage*.sh` and `step*.sh` scripts are retired and are not part of the supported self-hosting workflow.
