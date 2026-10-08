# Sayanox

### A completely original systems programming language with its own self-hosting compiler

**File extension: `.sa`** · Bootstrap written in Sayanox itself · Native AOT (x86-64 Linux)

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Language](https://img.shields.io/badge/Language-Sayanox-blue)](https://github.com/sayan9168/sayanox)
[![Status](https://img.shields.io/badge/Status-Active%20Development-orange)](docs/STATUS.md)

> Sayanox is designed to be **easy to read**, **easy to write**, and **powerful enough** for real systems work.  
> The compiler, tools, and most examples are written in Sayanox.

---

## Why Sayanox?

Most new languages are either:
- Too academic, or
- Thin wrappers around existing runtimes.

Sayanox aims for a clean middle ground:

- Simple, readable syntax
- Strong focus on **self-hosting** (the compiler is written in itself)
- Native code generation (AOT)
- Built-in tools: formatter + package manager written in Sayanox
- Educational + practical at the same time

---

## Quick Start

```sh
git clone https://github.com/sayan9168/sayanox.git
cd sayanox

make doctor          # check environment
make true-selfhost   # build the self-hosted compiler
make gen3            # gen3 == gen4 (byte-identical)
```

### Compile a program

```sh
# Using the Sayanox-written compiler (produces C)
./selfhost/gen2 examples/hello.sa hello.c
cc -o hello hello.c
./hello
```

### Native AOT (x86-64 Linux)

```sh
make native
./selfhost/native_aot examples/hello.sa hello
./hello
```

---

## Language Features (Current Milestone)

The **pure-min** dialect currently supports:

| Feature | Status |
|---------|--------|
| `hold` / `show` | ✅ |
| `when` / `while` | ✅ |
| `else` / `otherwise` | ✅ |
| Recursive functions (`make` / `give`) | ✅ |
| Integer + floating arithmetic | ✅ |
| Checked integer `%` | ✅ |
| Lists | ✅ |
| Nested structs | ✅ |
| Strings | ✅ |
| File / argument builtins | ✅ |
| Modules (`use "file.sa"`) | ✅ |
| Native AOT (x86-64 Linux) | ✅ (subset) |

See [docs/STATUS.md](docs/STATUS.md) for the full tested feature matrix and known limitations.

---

## Sayanox-written Tools

```sh
make tools

./tools/sxfmt input.sa formatted.sa     # formatter
./tools/sxpkg init                      # package manager
./tools/sxpkg add math 0.1.0
./tools/sxpkg list
```

The formatter currently handles whitespace. The package tool supports local `init` / `add` / `list` / `remove` / `search` / `info` / `seed`. Full registry support is still evolving — see [docs/ONLY_SAYANOX.md](docs/ONLY_SAYANOX.md).

---

## Project Layout

| Path | Role |
|------|------|
| `*.sa` | Sayanox source (compiler, tools, examples) |
| `selfhost/compiler_min.sa` | Maintained pure-min compiler written in Sayanox |
| `selfhost/seed/*.c` | C bootstrap seed |
| `selfhost/native_aot.c` | x86-64 Linux native-AOT backend |
| `Makefile` | Bootstrap, tests, verification |
| `docs/` | Status, design notes, language docs |

---

## GitHub Language Detection

Sayanox uses the `.sa` extension. GitHub Linguist does not yet have a built-in mapping for it, so the repository may show as C.  
See [docs/GITHUB_LANGUAGE.md](docs/GITHUB_LANGUAGE.md) for the upstream process.

---

## Roadmap (High Level)

- [x] Self-hosting pure-min dialect
- [x] Native AOT subset (x86-64 Linux)
- [x] Formatter + local package tool in Sayanox
- [ ] Full Stage-2 language self-hosting
- [ ] Broader platform support
- [ ] Standard library growth
- [ ] LSP support

---

## Contributing

This is an active research + engineering project. Issues and pull requests are welcome.

```sh
make doctor
make true-selfhost
make native-test
```

---

## License

MIT License © [Sayan Mahata](https://github.com/sayan9168) (Sayan the researcher)

---

<div align="center">

**Built by [Sayan the researcher](https://github.com/sayan9168)**  
[Portfolio](https://sayan9168.github.io) · [GrokOSINT](https://github.com/sayan9168/GrokOSINT)

</div>
