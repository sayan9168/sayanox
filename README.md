# Sayanox

Original language (`.sa`) by **Sayan Mahata**.

**No Rust. CLI logic in Sayanox (not Bash).** Host compiler is Stage-2 C → clang.

## Quick start

```sh
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
make stage2
make sx
./selfhost/sx_bin examples/hello.sa /tmp/hello 1
```

## Layout

- `selfhost/sx.sa` — CLI written in **Sayanox**
- `selfhost/stage2` — `.sa` → `.c` (C)
- `tools/*.sa` — tools in **Sayanox**

See [docs/NO_BASH.md](docs/NO_BASH.md).

MIT
