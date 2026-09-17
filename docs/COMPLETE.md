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

## 2. Production bootstrap (minimal C residual)

```sh
chmod +x selfhost/bootstrap_production.sh
./selfhost/bootstrap_production.sh
```

**Honest limit:** machine code still needs **clang** and a one-time **Stage-2 C** binary to lower Sayanox→C. There is no pure-Sayanox CPU codegen yet.

## 3. Legacy `.sh` cleanup

Prefer:

- `make stage2` / `make sx`
- `selfhost/sx.sa` / `codegen.sa`
- `bootstrap_production.sh`

Old `stageN_*.sh` scripts are obsolete; remove locally if present.

## 4. LSP + package registry

- `tools/sayanox-lsp.sh` — completion, hover, definition/diagnostic stubs
- `tools/sxpkg` — `registry` + `publish` local index under `.sx/registry`
