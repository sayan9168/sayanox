# Sayanox

**Sayanox** — original language (`.sa`). By **Sayan Mahata**.

## Quick start

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
./selfhost/restore_stage2.sh
./selfhost/sx examples/hello.sa --run
```

## Toolchain

| Tool | Role |
|------|------|
| Stage-2 | C compiler (`restore_stage2.sh` + `clang`) |
| `selfhost/sx` | compile / run `.sa` |
| `tools/sxfmt.sh` | formatter |
| `tools/sxpkg` | packages |
| `tools/sxrepl.sh` | REPL |

```bash
./tools/sxpkg init && ./tools/sxpkg install
cargo build --release --features native   # optional host native backend
```

See [docs/ABC_COMPLETE.md](docs/ABC_COMPLETE.md) and [docs/GC.md](docs/GC.md).

## License

MIT
