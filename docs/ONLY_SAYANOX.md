# Sayanox source and bootstrap boundaries

Sayanox programs use `.sa`. The maintained compiler source is
`selfhost/compiler_min.sa`; many examples and compiler experiments are also
written in Sayanox. This repository is moving more compiler and tooling work
into the language, but it is not yet accurate to claim every tool or backend
is written in Sayanox.

## What is currently Sayanox

- `selfhost/compiler_min.sa` — the maintained pure-min compiler source; the
  seed compiles it to C, and gen1-min/gen2 rebuild it from that source.
- `tools/sxfmt.sa` — a conservative, whitespace-only formatter. It is built
  by gen2 and covered by `make test-sxfmt`.
- `tools/sxpkg.sa` — local project/registry commands (`init`, `add`, `list`,
  `remove`, `seed`, `search`, `info`), built by gen2 and covered by
  `make test-sxpkg`; the shell entrypoint delegates these commands to it.
- `examples/*.sa` and `registry/*/main.sa` — sample programs and packages.
- Many files in `selfhost/*.sa` are compiler-stage experiments; most are not
  yet wired into the maintained build.

## What still is not Sayanox-owned

- `selfhost/seed/sxc_seed_min.c` — the trusted C bootstrap seed.
- `selfhost/native_aot.c` — the x86-64 Linux native-AOT implementation.
- `tools/sxpkg.sh` — online/package-directory behavior remains in shell;
  Sayanox currently owns only the local lock commands.
- `tools/sayanox-lsp.sh` — LSP logic is still implemented in shell.
- `Makefile` and POSIX-shell recipes — build/test orchestration.
- Generated C and native binaries — build outputs, not Sayanox source.

The verified portable program path is `.sa -> generated C -> host C compiler ->
executable`. The native-AOT path can skip the per-program C compiler for its
supported subset, but building its bootstrap still requires the host C toolchain.

## Target end state

1. Expand the Sayanox-written compiler to cover the full documented language.
2. Replace bootstrap/backend responsibilities incrementally, retaining tests
   and reproducible compiler rebuilds at every stage.
3. Keep the small trusted seed only as long as another validated bootstrap
   path needs it.

A language compiler always needs an initial executable somewhere in its
history. The practical goal is a small, auditable bootstrap and a Sayanox-built
toolchain that can reliably rebuild itself—not a claim that text runs without
any compiler or host tools.
