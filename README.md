# Sayanox

**Sayanox** — original language (`.sa`). By **Sayan Mahata**.

## Quick start (no Rust required)

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
./selfhost/restore_stage2.sh
./selfhost/sx examples/hello.sa --run
```

Needs: `bash`, `curl`, `clang` or `gcc`.

## Self-host

```bash
./selfhost/bootstrap_full_language_selfhost.sh
./selfhost/bootstrap_full_selfhost.sh
./selfhost/bootstrap_all.sh
```

## Tools

| Tool | Command |
|------|--------|
| CLI | `./selfhost/sx file.sa --run` |
| Format | `./tools/sxfmt.sh file.sa` |
| Packages | `./tools/sxpkg init && ./tools/sxpkg install` |
| REPL | `./tools/sxrepl.sh` |
| LSP | `./tools/sayanox-lsp.sh` |

## Optional Rust host

Zero external crates (std only). **Not required** for normal use.

```bash
cargo build --release   # optional
```

See [docs/RUST_OPTIONAL.md](docs/RUST_OPTIONAL.md).

## License

MIT
