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
- `tools/sxpkg.sa` — **the whole package tool**: `init`, `add`, `list`,
  `remove`, `seed`, `search`, `info`, `deps`, `verify`, `sum`, `install`,
  `install-local`, `publish`, the local-registry branches of `sync` and
  `fetch` (2026-10-18), the `ensure-dir`/`rm-tree`/`copy-tree` primitives the
  wrapper used to do with `mkdir`/`rm`/`cp`, and since 2026-10-22 `sign` and
  `authenticate` (HMAC-SHA256 over name/version/sha256, `stdlib/crypto.sa`),
  the online opt-in policy and the `SAYANOX_ROOT`/`SAYANOX_REGISTRY`/
  `SAYANOX_ONLINE` lookups. `tools/sxpkg.sh` was deleted on 2026-10-22, so
  there is no shell entrypoint left to delegate anything. Built by gen2 and
  covered by `make test-sxpkg`, `make test-sxpkg-wrapper`,
  `make test-sxpkg-polish`, `make test-sxpkg-crypto`,
  `make test-sxpkg-online-local`, `make test-sxpkg-transfer-hardening`,
  `make test-sxpkg-online-optin` and `make test-sxpkg-sayanox-logic`.
- `tools/sayanox_lsp.sa` — the language server, built by gen2 and covered by
  `make test-lsp` / `test-lsp-robust` / `test-lsp-workspace`.
- `tools/lsp_workspace_test.sa` — the LSP framed-session test client that
  replaced the C one; covered by `make test-lsp-workspace`.
- `tools/emit_to_ir.sa` — the portable IR listing for the native instruction
  log; covered by `make test-emit-to-ir` / `test-native-ir-portable`.
- `tools/sxlink.sa` — the native backend's ELF image writer and rel32 linker,
  byte-identical to the C `write_elf()` on its fixtures; covered by
  `make test-native-sxlink`.
- `tools/sxencode.sa` — the native backend's x86-64 instruction encoder,
  reverts the `SX_ENCODE_LOG` seam to the same fifty records and reproduces
  the whole code segment byte-for-byte; covered by
  `make test-native-sxencode`.
- `tools/sxdefs.sa` — the native backend's phase 1: the `use` splice and the
  struct/generic-struct/function/global tables, byte-identical to C's and
  refusing the same programs with the same words; covered by
  `make test-native-sxdefs`.
- `tools/native32.sa` — a whole second and third **machine target** written in
  Sayanox: i386 Linux ELF and aarch64 ELF64 for a documented integer subset.
  The i386 images run here; the aarch64 images are pinned against goldens and
  **never executed** (no ARM hardware or emulator). Covered by
  `make test-native32` and `make test-native-arm64`.
- `tools/sxmod.sa` — the module-namespacing pass: `module NAME from "path"` +
  `alias.member` rewritten into prefixed flat declarations before compilation.
  Covered by `make test-sxmod`.
- `tools/sxaudit.sa` — the auditor for the C seed: it recomputes the seed's
  size and SHA-256 with `stdlib/crypto.sa` and the gate compares them with the
  tracked pin `selfhost/seed/sxc_seed_min.audit`. Covered by
  `make test-trust-anchor`.
- `stdlib/*.sa` — ten modules, including the nested JSON reader
  (`json_deep.sa`) and SHA-256/HMAC-SHA256 (`crypto.sa`), byte-identical on
  seed, gen2 and native. Covered by `make test-stdlib-json-deep` and
  `make test-stdlib-crypto`.
- `tools/sxdiag.sa` — the four negative-diagnostic suites (inline list
  arguments, list postfix arguments, unproved return paths, unbound names and
  unknown callees), which were four `.sh` drivers until 2026-10-21; covered by
  `make test-sxdiag`.
- `examples/*.sa` and `registry/*/main.sa` — sample programs and packages.
- Many files in `selfhost/*.sa` are compiler-stage experiments; most are not
  yet wired into the maintained build.

## What still is not Sayanox-owned

- `selfhost/seed/sxc_seed_min.c` — the trusted C bootstrap seed. Since
  2026-10-23 it is a *pinned* exception rather than an open question:
  `make test-trust-anchor` fixes its size and SHA-256 (recomputed by
  Sayanox, `tools/sxaudit.sa` + `stdlib/crypto.sa`), its four standard
  headers, the absence of any process/network/dynamic-loading call, and the
  single `popen` site — which lives in the *runtime text the seed emits*
  (`sx_http`, behind `http_get`), not in the compiler
  ([ALL_SAYANOX_PHASE.md](ALL_SAYANOX_PHASE.md#phase-e-decision-2026-10-23-option-2-and-it-is-now-measured)).
- `selfhost/native_aot.c` — the x86-64 Linux native-AOT implementation. Its
  ELF writer, rel32 linker and instruction encoder now exist in Sayanox
  (`tools/sxlink.sa`, `tools/sxencode.sa`) and are proved byte-identical, but
  the C file still produces the executables: the scanner, parser, type
  inference, emit tree, runtime stubs and collector are unported. Phase 1 —
  the `use` splice and the definition tables — is Sayanox too since 2026-10-23
  (`tools/sxdefs.sa`), on the same proved-equal-but-not-wired-in footing.
  Still C and unported: kind inference, the emit tree, the 856-line emitted
  runtime and the 339-line collector.
- The http(s) transport itself — `curl`, or `wget` when there is no curl.
  Everything *around* it is Sayanox since 2026-10-22: `tools/sxpkg.sa` is the
  whole package tool, with `getenv` for SAYANOX_ROOT/SAYANOX_REGISTRY/
  SAYANOX_ONLINE and `run_command` to start the transport it found on PATH.
  `tools/sxpkg.sh` is deleted. `test-sxpkg-transfer-hardening` still pins
  curl/wget as the transport, which is a decision about which program is
  allowed to open a socket, not about who writes the policy.
- `Makefile` and POSIX-shell recipes — build/test orchestration. All tracked
  scripts are `#!/bin/sh`; bash, awk and sed are not part of the maintained
  toolchain (`make test-language-deps`).
- Generated C and native binaries — build outputs, not Sayanox source.

The verified portable program path is `.sa -> generated C -> host C compiler ->
executable`. The native-AOT path can skip the per-program C compiler for its
supported subset, but building its bootstrap still requires the host C toolchain.

## Target end state

The short, gate-by-gate version of what is done and what is left is the two
status tables in [`../README.md`](../README.md#status).

Writing every remaining piece in Sayanox is the **next phase**; the plan, the
measured inventory and the phase order are in
[`ALL_SAYANOX_PHASE.md`](ALL_SAYANOX_PHASE.md). `make all-sayanox` prints what
is left and fails closed.

| Phase | Work | Gate |
|---|---|---|
| A (done 2026-10-17) | Compiler, formatter, package tool, language server, LSP binder in `.sa`; no bash/awk/sed/Python on maintained paths | `test-language-deps` |
| B (done 2026-10-17; +B.5 2026-10-21) | `tools/emit_to_ir` in Sayanox; directory builtins + Sayanox folder index (C header and binder deleted); process builtins + Sayanox LSP test client (the last C file in `tools/` deleted); `run_command(cmd)` + `tools/sxdiag` replacing four `sh` diagnostic drivers | `test-emit-to-ir`, `test-native-ir-portable`, `test-path-builtins`, `test-proc-builtins`, `test-lsp`, `test-lsp-workspace`, `test-sxdiag` |
| C (file side done 2026-10-18) | publish, install-local, local sync/fetch, seed folders and the folder primitives moved to `tools/sxpkg.sa`. The http(s) transport stays in the shell: `test-sxpkg-transfer-hardening` pins curl/wget as the transport (the argv obstacle went away with `run_command(cmd)` on 2026-10-21; the policy did not) | `test-sxpkg*` unchanged, plus `test-sxpkg-sayanox-logic` |
| D (started 2026-10-18) | Step 1: the byte-buffer + bitwise surface (`write_bytes`, `bytes_f64`, `bit_and`, `bit_or`, `bit_xor`, `bit_not`, `shl`, `shr`) and its reader `read_bytes`. Step 2–4 (2026-10-20/21): the backend's ELF image writer + rel32 linker (`tools/sxlink.sa`, `SX_LINK_DUMP` where `SX_EMIT_LOG` leaves off) and its x86-64 instruction encoder (`tools/sxencode.sa`, `SX_ENCODE_LOG`). Step 5 (2026-10-23): the backend's **phase 1** — `use` expansion and `collect_defs()` — reads the program text itself (`tools/sxdefs.sa`, `SX_DEFS_DUMP`), byte-identical tables and identical diagnostics. Not yet ported: kind inference, the emit tree, the runtime stubs and the collector of `selfhost/native_aot.c` | `test-native-primitives`, `test-read-bytes`, `test-native-emit-split`, `test-native-ir-log`, `test-native-sxlink`, `test-native-sxencode`, `test-native-sxdefs`, `native-test` |
| E (decided 2026-10-23, option 2) | The minimal C seed stays as a **documented, auditable, pinned** exception: one file, 2176 lines, SHA-256 pinned and recomputed by Sayanox, four headers, no process/network call, deterministic output, and the one emitted `popen` site counted. Option 1 (a prebuilt binary rebuilt from `.sa`) still needs Phase D. C is still the trust anchor — now a measured one | `make test-trust-anchor`, `make all-sayanox` (still exits 1) |

1. Expand the Sayanox-written compiler to cover the full documented language.
2. Replace bootstrap/backend responsibilities incrementally, retaining tests
   and reproducible compiler rebuilds at every stage.
3. Keep the small trusted seed only as long as another validated bootstrap
   path needs it — and, while it is kept, keep it pinned
   (`make test-trust-anchor`).

A language compiler always needs an initial executable somewhere in its
history. The practical goal is a small, auditable bootstrap and a Sayanox-built
toolchain that can reliably rebuild itself—not a claim that text runs without
any compiler or host tools.
