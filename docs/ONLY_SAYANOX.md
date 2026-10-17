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
- `tools/sayanox_lsp.sa` — the language server, built by gen2 and covered by
  `make test-lsp` / `test-lsp-robust` / `test-lsp-workspace`.
- `tools/lsp_workspace_bind.sa` — the build-time binder that installs the
  tool-local directory bridge into the generated LSP C. It replaced an awk
  script and produces byte-identical output.
- `examples/*.sa` and `registry/*/main.sa` — sample programs and packages.
- Many files in `selfhost/*.sa` are compiler-stage experiments; most are not
  yet wired into the maintained build.

## What still is not Sayanox-owned

- `selfhost/seed/sxc_seed_min.c` — the trusted C bootstrap seed.
- `selfhost/native_aot.c` — the x86-64 Linux native-AOT implementation.
- `tools/sxpkg.sh` — online/package-directory behavior remains in POSIX shell;
  Sayanox currently owns only the local lock commands.
- `Makefile` and POSIX-shell recipes — build/test orchestration. All tracked
  scripts are `#!/bin/sh`; bash, awk and sed are not part of the maintained
  toolchain (`make test-language-deps`).
- Generated C and native binaries — build outputs, not Sayanox source.

The verified portable program path is `.sa -> generated C -> host C compiler ->
executable`. The native-AOT path can skip the per-program C compiler for its
supported subset, but building its bootstrap still requires the host C toolchain.

## Target end state

Writing every remaining piece in Sayanox is the **next phase**; the plan, the
measured inventory and the phase order are in
[`ALL_SAYANOX_PHASE.md`](ALL_SAYANOX_PHASE.md). `make all-sayanox` prints what
is left and fails closed.

| Phase | Work | Gate |
|---|---|---|
| A (done 2026-10-17) | Compiler, formatter, package tool, language server, LSP binder in `.sa`; no bash/awk/sed/Python on maintained paths | `test-language-deps` |
| B (started 2026-10-17) | `tools/emit_to_ir` in Sayanox (**done**); directory builtin + LSP bridge next | `test-emit-to-ir`, `test-native-ir-portable`, `test-lsp`, `test-lsp-workspace` (byte-identical output first) |
| C | Online package behavior moves from `tools/sxpkg.sh` to `tools/sxpkg.sa` | `test-sxpkg*` unchanged |
| D | `selfhost/native_aot.c` reimplemented in Sayanox against the pinned IR listing | `test-native-test`, `test-native-ir-log` |
| E | Seed decision: prebuilt trust anchor or a documented C exception | `make all-sayanox` |

1. Expand the Sayanox-written compiler to cover the full documented language.
2. Replace bootstrap/backend responsibilities incrementally, retaining tests
   and reproducible compiler rebuilds at every stage.
3. Keep the small trusted seed only as long as another validated bootstrap
   path needs it.

A language compiler always needs an initial executable somewhere in its
history. The practical goal is a small, auditable bootstrap and a Sayanox-built
toolchain that can reliably rebuild itself—not a claim that text runs without
any compiler or host tools.
