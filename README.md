# Sayanox

**Sayanox** — original language (`.sa`). By **Sayan Mahata**.

## Quick start

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
./selfhost/restore_stage2.sh
./selfhost/sx examples/hello.sa --run
```

## Self-host

```bash
./selfhost/bootstrap_full_language_selfhost.sh   # hold/show/when/while in Sayanox
./selfhost/bootstrap_full_selfhost.sh            # Stage-3 loop
./selfhost/bootstrap_all.sh                      # everything smoke
```

## Tools

| Tool | Command |
|------|--------|
| CLI | `./selfhost/sx file.sa --run` |
| Format | `./tools/sxfmt.sh file.sa` |
| Packages | `./tools/sxpkg init && ./tools/sxpkg install` |
| Lock | `./tools/sxpkg lock` → `sx.lock` |
| REPL | `./tools/sxrepl.sh` |
| LSP | `./tools/sayanox-lsp.sh` |

Optional native host: `cargo build --release --features native`

See [docs/STATUS.md](docs/STATUS.md).

## License

MIT
