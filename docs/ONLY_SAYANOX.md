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
- `tools/sxpkg.sa` — project/registry commands (`init`, `add`, `list`,
  `remove`, `seed`, `search`, `info`, `deps`, `verify`, `install`,
  `install-local`, `publish`) plus, since 2026-10-18, the local-registry
  branches of `sync` and `fetch` and the `ensure-dir`/`rm-tree`/`copy-tree`
  primitives the wrapper used to do with `mkdir`/`rm`/`cp`. Built by gen2 and
  covered by `make test-sxpkg`, `make test-sxpkg-wrapper`,
  `make test-sxpkg-polish`, `make test-sxpkg-online-local`,
  `make test-sxpkg-transfer-hardening`, `make test-sxpkg-online-optin` and
  `make test-sxpkg-sayanox-logic`; the shell entrypoint delegates these
  commands to it.
- `tools/sayanox_lsp.sa` — the language server, built by gen2 and covered by
  `make test-lsp` / `test-lsp-robust` / `test-lsp-workspace`.
- `examples/*.sa` and `registry/*/main.sa` — sample programs and packages.
- Many files in `selfhost/*.sa` are compiler-stage experiments; most are not
  yet wired into the maintained build.

## What still is not Sayanox-owned

- `selfhost/seed/sxc_seed_min.c` — the trusted C bootstrap seed.
- `selfhost/native_aot.c` — the x86-64 Linux native-AOT implementation.
- `tools/sxpkg.sh` — the http(s) transport (curl/wget) and the online opt-in
  policy remain in POSIX shell. Sayanox cannot replace them yet: `spawn(path)`
  takes no arguments, so it cannot pass a URL to curl or wget, and the
  hardening gate pins curl/wget as the transport it must keep using.
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
| B (done 2026-10-17) | `tools/emit_to_ir` in Sayanox; directory builtins + Sayanox folder index (C header and binder deleted); process builtins + Sayanox LSP test client (the last C file in `tools/` deleted) | `test-emit-to-ir`, `test-native-ir-portable`, `test-path-builtins`, `test-proc-builtins`, `test-lsp`, `test-lsp-workspace` |
| C (file side done 2026-10-18) | publish, install-local, local sync/fetch, seed folders and the folder primitives moved to `tools/sxpkg.sa`. The http(s) transport stays in the shell: `spawn` takes no argv, and `test-sxpkg-transfer-hardening` pins curl/wget | `test-sxpkg*` unchanged, plus `test-sxpkg-sayanox-logic` |
| D (started 2026-10-18) | Step 1: the byte-buffer + bitwise surface (`write_bytes`, `bytes_f64`, `bit_and`, `bit_or`, `bit_xor`, `bit_not`, `shl`, `shr`). Step 2, not started: `selfhost/native_aot.c` itself, reimplemented in Sayanox against the pinned IR listing | `test-native-primitives` (step 1), `test-native-test`, `test-native-ir-log` |
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
