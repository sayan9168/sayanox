# Sayanox

Original language (`.sa`) by **Sayan Mahata**.

## Quick start

```sh
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
make stage2
bash selfhost/bootstrap_production.sh
./selfhost/sx examples/hello.sa --run
```

Native subset (no Stage-2 after one build):

```sh
make native
make bootstrap-native
```

## Supported scripts / targets

| Path | Role |
|------|------|
| `make stage2` | Stage-2 host |
| `make native` / `make bootstrap-native` | Native AOT subset |
| `selfhost/restore_stage2.sh` | Stage-2 restore |
| `selfhost/bootstrap_production.sh` | Production codegen smoke |
| `selfhost/bootstrap_full_selfhost.sh` | Full self-host |
| `selfhost/bootstrap_full_language_selfhost.sh` | Full-language self-host |
| `selfhost/bootstrap_native_only.sh` | Native-only smoke |
| `selfhost/codegen_struct_list_test.sh` | Codegen struct/list test |
| `selfhost/sx` | CLI runner |
| `tools/sxfmt.sh`, `tools/sxpkg`, `tools/sayanox-lsp.sh`, `tools/sxrepl.sh` | Dev tools |

Obsolete `stageN_*.sh` / `step*.sh` / cycle / run_sayanoxc scripts are removed.

MIT
