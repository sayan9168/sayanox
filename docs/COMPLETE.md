# Completion status

## 1. codegen.sa — multi-var / modules / list markers

- **Multi-var:** up to 8 slots (`v0`–`v7`) by first letter of name (`a`→0 …)
- **when / while:** emitted
- **use / list:** recognized (marker comments; full lowering still Stage-2)
- Demo: `selfhost/multi_demo.sa` → 10 and 32

```sh
echo -n selfhost/multi_demo.sa > selfhost/SX_TARGET
./selfhost/stage2 selfhost/codegen.sa host.c && clang -o host host.c && ./host
clang -o out selfhost/codegen_emit.c && ./out
```

## 2. Production bootstrap

```sh
make stage2
bash selfhost/bootstrap_production.sh
```

The supported path keeps the Stage-2 C host boundary explicit while the compiler backend is being moved toward a fully self-hosted implementation.

## 3. Supported self-host tooling

- `selfhost/restore_stage2.sh` or `make stage2` — Stage-2 bootstrap.
- `selfhost/bootstrap_production.sh` — production codegen smoke path.
- `selfhost/bootstrap_full_selfhost.sh` — full self-host bootstrap.
- `selfhost/bootstrap_full_language_selfhost.sh` — full-language self-host bootstrap.
- `selfhost/sx` and documented `tools/` utilities — normal developer workflow.

Numbered `stage*.sh` and `step*.sh` scripts have been removed. They are not supported entry points and should not be recreated for normal development.

## 4. LSP + package registry

- `tools/sayanox-lsp.sh` — completion, hover, definition/diagnostic stubs
- `tools/sxpkg` — `registry` + `publish` local index under `.sx/registry`
