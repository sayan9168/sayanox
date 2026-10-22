<div align="center">

<img src="assets/sayanox-logo-256.png" alt="Sayanox" width="120" height="120" />

# Sayanox

### A completely original systems programming language with its own self-hosting compiler

**File extension: `.sa`** · Bootstrap written in Sayanox itself · Native AOT (x86-64 Linux)

[![License: Sayanox](https://img.shields.io/badge/License-Sayanox%20v1.1-blue.svg)](LICENSE)
[![Language](https://img.shields.io/badge/Language-Sayanox-blue)](https://github.com/sayan9168/sayanox)
[![Status](https://img.shields.io/badge/Status-Active%20Development-orange)](docs/STATUS.md)

</div>

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

The formatter currently handles whitespace. The package tool is one Sayanox
program, `tools/sxpkg.sa` (built to `./tools/sxpkg` by `make sxpkg`): `init`,
`add`, `list`, `remove`, `seed`, `search`, `info`, `deps`, `verify`, `sum`,
`publish`, `install`, `install-local`, `sync`, `fetch`, the online opt-in
policy, `SAYANOX_ROOT`/`SAYANOX_REGISTRY`/`SAYANOX_ONLINE`, and its own exit
statuses. Its shell wrapper was deleted on 2026-10-22; the only program it
still starts is the transport itself, `curl` or `wget`. Full registry support
is still evolving — see [docs/ONLY_SAYANOX.md](docs/ONLY_SAYANOX.md).

The language server (`tools/sayanox_lsp.sa`), its folder index, the IR
translator (`tools/emit_to_ir.sa`), two pieces of the native backend - its
ELF image writer with its rel32 linker (`tools/sxlink.sa`) and its x86-64
instruction encoder (`tools/sxencode.sa`) - and the negative-diagnostic test
suites (`tools/sxdiag.sa`) are Sayanox programs too, and no maintained build or
test path needs bash, awk, sed or Python (`make test-language-deps`). Driving
another program used to require the shell, because `spawn(path)` takes no
arguments; since 2026-10-21 `run_command(cmd)` gives a Sayanox program the exit
status of a command line, which is what let four `sh` test drivers and then the
whole package tool move over, and since 2026-10-22 `getenv(name)` lets it read
the environment the wrappers used to read.

---

## Project Layout

| Path | Role |
|------|------|
| `*.sa` | Sayanox source (compiler, tools, examples) |
| `selfhost/compiler_min.sa` | Maintained pure-min compiler written in Sayanox |
| `selfhost/seed/*.c` | C bootstrap seed |
| `selfhost/native_aot.c` | x86-64 Linux native-AOT backend |
| `tools/sxlink.sa` | Sayanox ELF image writer + rel32 linker for that backend |
| `tools/sxencode.sa` | Sayanox x86-64 instruction encoder for that backend |
| `tools/sxdiag.sa` | Sayanox negative-diagnostic suites (replaced four `sh` drivers) |
| `Makefile` | Bootstrap, tests, verification |
| `docs/` | Status, design notes, language docs |

---

## Language on GitHub

The badge above says **Language: Sayanox** because that is what the source is.
GitHub's own language bar may still say **C**, and that is expected.

Sayanox uses the `.sa` extension, which is not yet registered in
[github-linguist](https://github.com/github-linguist/linguist)'s
`languages.yml`. Linguist only counts languages it knows, so the 173 `.sa`
files — about 758 KB, roughly 65% of this repository's source — contribute
nothing to the bar today, and what is left is the hand-written C seed, the
`Makefile` and the shell scripts. A `.gitattributes` cannot register a new
language; only an upstream Linguist change can, so **the bar will keep showing
C until that change is merged**.

`.sa` is deliberately not mapped to Python, C or any other existing language to
make the statistics look better — that would mislabel the source.

Everything needed for the upstream contribution is prepared in this repository:
`.gitattributes`, `samples/Sayanox/`, `grammars/sayanox.tmLanguage.json`, the
exact `languages.yml` snippet, a PR checklist and draft PR text. See
**[docs/LINGUIST.md](docs/LINGUIST.md)** — including the honest assessment of
why the pull request has not been opened yet (Linguist requires demonstrated
in-the-wild usage of an extension). [docs/GITHUB_LANGUAGE.md](docs/GITHUB_LANGUAGE.md)
has the short version.

---

## Roadmap (High Level)

- [x] Self-hosting pure-min dialect
- [x] Native AOT subset (x86-64 Linux)
- [x] Formatter + local package tool in Sayanox
- [x] Language server in Sayanox (bounded local workspace index)
- [x] Toolchain free of bash, awk, sed and Python (`make test-language-deps`)
- [ ] **Next phase — all-in-Sayanox toolchain** ([plan](docs/ALL_SAYANOX_PHASE.md)):
      port the remaining C pieces (native backend, seed) and the build driver
      into Sayanox. The IR translator, the LSP folder index and the byte-buffer
      + bitwise builtins already moved (2026-10-17 / 2026-10-18);
      `make all-sayanox` fails closed until the rest does
- [ ] Full Stage-2 language self-hosting
- [ ] Broader platform support
- [ ] Standard library growth

### Next phase: everything in Sayanox

The maintained *logic* is already Sayanox: the compiler
(`selfhost/compiler_min.sa`), the formatter, the package tool, the language
server and its framed-session test client. Since 2026-10-17 no maintained path
needs bash, awk, sed or Python either.

What is still not Sayanox is small, measurable, and listed in
[docs/ALL_SAYANOX_PHASE.md](docs/ALL_SAYANOX_PHASE.md): the 2,035-line C seed,
the 4,415-line C native backend, and the make/POSIX-sh build driver. On
2026-10-17 the 150-line C IR translator became `tools/emit_to_ir.sa` with
byte-identical output, the LSP folder index moved into Sayanox (the C
directory header and its binder were deleted), the 127-line C framed-session
test client became `tools/lsp_workspace_test.sa` on the new process builtins,
and ten unreferenced legacy C files were removed. On 2026-10-18 the language
gained the byte-buffer and bitwise surface the native backend needs
(`write_bytes`, `bytes_f64`, `bit_and`, `bit_or`, `bit_xor`, `bit_not`,
`shl`, `shr`); `make test-native-primitives` proves it by running a static
x86-64 ELF that a Sayanox program emitted with those calls alone. On 2026-10-20
that surface gained its reader (`read_bytes`, because `read_file` stops at the
first NUL and an ELF image is mostly NULs) and the native backend's ELF image
writer and rel32 linker became Sayanox: `tools/sxlink.sa` links five fixtures
byte-identically to the C `write_elf()` and its output runs, gated by
`make test-native-sxlink` against a `SX_LINK_DUMP` seam that changes no emitted
byte. On 2026-10-21 the encoder followed: `tools/sxencode.sa` replays the
`SX_ENCODE_LOG` seam and reproduces the code segment of five fixtures
byte-for-byte with the same fifty-record vocabulary, gated by
`make test-native-sxencode`. `make all-sayanox` prints the remaining
inventory and **fails closed** — the same way `true-selfhost-full` refuses to
claim a full-language self-host — so the remaining work cannot silently drift
or be forgotten. The plan orders it: ~~IR tool~~, ~~directory bridge~~, then
the package wrapper, then the native backend, and the seed last.

---

## Logo

<p align="center">
  <img src="assets/sayanox-logo-256.png" alt="Sayanox mark" width="96" height="96" />
</p>

The mark is a rounded-square badge on an indigo&nbsp;→&nbsp;cyan gradient,
carrying a geometric <strong>S</strong> built from two 270-degree circular arcs.
It is the boot chain made visible: a self-hosting compiler has to be folded out
of itself, and two arcs whose tangents meet eastward at the waist are the
smallest shape that says so without drawing a compiler.

The full set — vector masters, rasters, the wordmark lockup and a 1280×640
social card — lives in [`assets/`](assets/), with the palette, the exact
geometry and the usage notes in [`assets/README.md`](assets/README.md).

```html
<!-- the mark, at any size -->
<img src="assets/sayanox-logo.svg" alt="Sayanox" width="64" />

<!-- wordmark lockup, for a dark or coloured ground -->
<img src="assets/sayanox-lockup.svg" alt="Sayanox" height="48" />

<!-- browser tab icon -->
<link rel="icon" type="image/svg+xml" href="assets/favicon.svg" />
```

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

[Sayanox License v1.1](LICENSE) © [Sayan](https://github.com/sayan9168) (sayan9168)

Full text: [LICENSE](LICENSE) · License home: [sayanox-license](https://github.com/sayan9168/sayanox-license)

---

<div align="center">

**Built by [Sayan the researcher](https://github.com/sayan9168)**  
[Portfolio](https://sayan9168.github.io) · [GrokOSINT](https://github.com/sayan9168/GrokOSINT)

</div>
