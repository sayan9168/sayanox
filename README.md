# Sayanox

**Sayanox is the language.** Programs and the compiler are written in **`.sa`**.

Other files (small C seed, Makefile) exist only so a computer can **bootstrap** the first binary — the same necessity every language has.

See [docs/ONLY_SAYANOX.md](docs/ONLY_SAYANOX.md).

## Quick start

```sh
git clone https://github.com/sayan9168/sayanox.git
cd sayanox

# One-time seed (not “writing in C as the language”)
make native

# Then only Sayanox programs:
./selfhost/native_aot examples/native_hello.sa hello
./hello
```

Full language path:

```sh
make stage2
make sx
./selfhost/sx examples/hello.sa --run
```

## Layout

| Path | Role |
|------|------|
| `*.sa` | **The language** — compiler, tools, demos |
| `selfhost/native_*` / Stage-2 C | **Bootstrap seed only** |
| `Makefile` | Build the seed once |

MIT — Sayan Mahata
