# Status

| Item | State |
|------|--------|
| Multi-var codegen.sa | done (8 slots) |
| use/list markers | done |
| Production bootstrap | supported (`bootstrap_production.sh`) |
| Stage-2 build | supported (`make stage2` / `restore_stage2.sh`) |
| Full self-host bootstrap | supported (`bootstrap_full_selfhost.sh`) |
| Full-language self-host bootstrap | supported (`bootstrap_full_language_selfhost.sh`) |
| LSP | done (stdio MVP+) |
| Package registry | local `.sx/registry` |
| Zero C host | **not possible yet** (need ISA backend) |
| Legacy stage/step shell scripts | removed |

## Supported commands

```sh
make stage2
bash selfhost/bootstrap_production.sh
```

For normal compilation after Stage-2 is available:

```sh
./selfhost/sx examples/hello.sa --run
```

Numbered `selfhost/stage*.sh` and `selfhost/step*.sh` scripts are obsolete and have been removed. CI and the documented build path do not depend on them.
