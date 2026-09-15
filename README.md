# Sayanox

**Sayanox** — original language (`.sa`). By **Sayan Mahata**.

## Quick start

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
./selfhost/restore_stage2.sh
./selfhost/sx examples/hello.sa --run
```

## A / B / C

See [docs/ABC_COMPLETE.md](docs/ABC_COMPLETE.md).

| Track | Summary |
|-------|--------|
| **A** codegen depth | struct/list/expr via `sx`; subset in `codegen.sa` |
| **B** bootstrap | Stage-2 C host + `.sa` tools |
| **C** ecosystem | `tools/sxpkg`, `tools/sayanox-lsp.py`, Cranelift `--features native`, [docs/GC.md](docs/GC.md) |

```bash
# packages
./tools/sxpkg init && ./tools/sxpkg install

# LSP MVP
python3 tools/sayanox-lsp.py

# optional native
cargo build --release --features native
```

## License

MIT
