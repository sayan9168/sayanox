# Sayanox

**Sayanox is the language.** Programs and the compiler are written in **`.sa`**.

Other files (small C seed, Makefile) exist only so a computer can **bootstrap** the first binary — the same necessity every language has.

See [docs/ONLY_SAYANOX.md](docs/ONLY_SAYANOX.md).

## Quick start

```sh
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
make true-selfhost          # seed-min -> gen1_min -> gen2 -> tests
make gen3                   # gen3 == gen4 byte-identical
```

Then compile a Sayanox program with a Sayanox-written compiler:

```sh
./selfhost/gen2 examples/hello.sa hello.c && cc -o hello hello.c && ./hello
```

## Status (honest)

The **pure-min** dialect is self-hosting and reproducible: `hold / show /
when / while`, `otherwise` and its `else` alias, `make / give` (with
recursion), lists (`[..]`, `xs[i]`, `len`, `push`), numeric structs with named
fields, `%`, and `use "file.sa"` modules. See
[docs/STATUS.md](docs/STATUS.md) for the verified seed-min / gen2 / native
table — including nested structs and every measured divergence between the
three backends — and for what is explicitly *not* supported (fractional
literals, parenthesized base expressions in gen2, namespaced modules, a full
standard library).

## Layout

| Path | Role |
|------|------|
| `*.sa` | **The language** — compiler, tools, demos |
| `selfhost/compiler_min.sa` | the pure-min compiler in Sayanox (gen2 source) |
| `selfhost/seed/*.c` | bootstrap seed only |
| `selfhost/native_aot.c` | x86-64 backend (limited subset, rejects the rest) |
| `Makefile` | the only entry point |

MIT — Sayan Mahata
