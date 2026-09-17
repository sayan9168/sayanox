# Sayanox

**Sayanox** — original language (`.sa`). By **Sayan Mahata**.

**No Rust. Core path: Sayanox + C (no Bash scripts required).**

## Quick start

```bash
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
make stage2
make sx
./selfhost/sx_bin examples/hello.sa /tmp/hello 1
```

Needs: `clang` or `gcc`, `make` optional.

## How it works

1. `stage2` (C) compiles `.sa` → `.c`
2. `sx.sa` (Sayanox) drives compile + link + run via `run` / `arg`
3. `clang` produces the binary

See [docs/NO_BASH.md](docs/NO_BASH.md).

## License

MIT
