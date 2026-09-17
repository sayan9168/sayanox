# Sayanox

**Sayanox** — original language (`.sa`). By **Sayan Mahata**.

**No Rust. No Cargo.** Compiler path is Stage-2 (C) + `sx`.

## Quick start

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

## License

MIT
