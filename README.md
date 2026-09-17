# Sayanox

Original language (`.sa`) by **Sayan Mahata**.

## Quick start

```sh
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
make stage2
bash selfhost/bootstrap_production.sh
```

For normal `.sa` compilation after Stage-2 is built:

```sh
./selfhost/sx examples/hello.sa --run
```

## Supported build paths

- `make stage2` — builds the Stage-2 compiler from `selfhost/build_stage2.c`.
- `bash selfhost/restore_stage2.sh` — restores/builds the Stage-2 compiler directly.
- `bash selfhost/bootstrap_production.sh` — runs the supported production codegen smoke path.
- `bash selfhost/bootstrap_full_selfhost.sh` — full self-host bootstrap path.
- `bash selfhost/bootstrap_full_language_selfhost.sh` — full-language self-host bootstrap path.
- `selfhost/sx` — normal command-line compiler runner.
- `tools/` — documented developer tools.

Legacy numbered `stage*.sh` and `step*.sh` scripts are no longer part of the supported toolchain.

## Features

- Stage-2 full grammar (C host → clang)
- **codegen.sa** multi-var self-host path
- `sx.sa` CLI, `sxpkg` + local **registry**, **LSP**
- No Rust required for the supported bootstrap path

See [docs/COMPLETE.md](docs/COMPLETE.md).

MIT
