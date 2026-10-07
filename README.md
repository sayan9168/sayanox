# Sayanox

Sayanox is a programming language whose source files use the `.sa` extension.
The maintained bootstrap compiler and most examples are written in Sayanox; C
is still used for the bootstrap seed and the current native-AOT backend.

## Quick start

```sh
git clone https://github.com/sayan9168/sayanox.git
cd sayanox
make doctor
make true-selfhost
make gen3                   # gen3 == gen4 byte-identical
```

Compile a program with the Sayanox-written compiler:

```sh
./selfhost/gen2 examples/hello.sa hello.c
cc -o hello hello.c
./hello
```

For the tested x86-64 Linux native-AOT subset:

```sh
make native
./selfhost/native_aot examples/hello.sa hello
./hello
```

## Sayanox-written tools

The formatter and the local package-lock tool are themselves Sayanox programs;
`make tools` compiles them through gen2:

```sh
make tools
./tools/sxfmt input.sa formatted.sa
./tools/sxpkg init
./tools/sxpkg add math 0.1.0
./tools/sxpkg list
```

The formatter currently changes whitespace only. The Sayanox package tool supports local `init`/`add`/`list`/`remove`/
`search`/`info`/`seed`; sync/install/publish/fetch still use the shell
implementation. See [docs/ONLY_SAYANOX.md](docs/ONLY_SAYANOX.md)
for the full migration boundary.

## Current supported milestone

The seed-min and gen2 compilers implement the tested **pure-min** dialect:
`hold`/`show`, `when`/`while`, `else`/`otherwise`, numeric recursive
`make`/`give` functions, integer and fractional double arithmetic, checked
integer `%`, lists, nested structs, strings, file/argument builtins, and
textual `use "file.sa"` modules. `make native-test` checks the documented
native-AOT subset and parity where supported.

See [docs/STATUS.md](docs/STATUS.md) for the tested feature matrix, known
backend differences, and exact commands. The full Stage-2 language is not yet
self-hosted; the shared bootstrap subset does not include every syntax form or
library shown in older experiments. Native AOT currently targets x86-64 Linux.

## GitHub language display

Sayanox source files are `.sa`, but GitHub Linguist currently has no Sayanox
language entry or `.sa` mapping. A repository-only `.gitattributes` override
cannot register a new language; see [docs/GITHUB_LANGUAGE.md](docs/GITHUB_LANGUAGE.md)
for the required upstream step and current status.

## Layout

| Path | Role |
|------|------|
| `*.sa` | Sayanox programs, tools, examples and compiler sources |
| `selfhost/compiler_min.sa` | the maintained pure-min compiler written in Sayanox |
| `selfhost/seed/*.c` | C bootstrap seed |
| `selfhost/native_aot.c` | x86-64 Linux native-AOT implementation |
| `Makefile` | bootstrap, regression tests and verification entry points |

MIT — Sayan Mahata
