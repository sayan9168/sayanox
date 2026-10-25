# Sayanox-owned tooling: migration status

The project goal is to move compiler and developer-tool **logic** into
Sayanox. All tracked shell scripts have now been retired (2026-10-25), but the
Makefile still contains inline POSIX-shell recipes and the bootstrap retains a
base64/gzip compiler-source recovery fallback. Do not read this as a claim that
the host build driver is itself a Sayanox program.

## No tracked `.sh` scripts; no bash, awk or sed on maintained paths

* `git ls-files '*.sh'` is empty. The last 14 tracked drivers have Sayanox
  replacements: `tools/sxsuite.sa`, `tools/sxlsp_probe.sa`,
  `tools/sxpkg_transfer_test.sa`, `tools/sxnet_test.sa`, and `tools/sxpack.sa`.
  `make test-trust-anchor` and `make test-language-deps` pin this invariant.
  The bootstrap-source fallback remains an inline Makefile recipe because the
  Sayanox packer cannot be built before a compiler exists.
* The LSP build needs no binder at all since 2026-10-17: the folder index is
  Sayanox (`read_dir`/`path_kind`/`path_size`/`path_real`), so both
  `tools/lsp_workspace_bind.sa` (itself a Sayanox replacement for the old awk
  binder) and the C header it injected were deleted.
* The offline packer and restorer are `tools/sxpack.sa` (Base64 encode/decode,
  1100-character parts, gzip stream recovery and byte-for-byte archive checks).
  The regression probes and local HTTP/crawler tests are also Sayanox programs.
  Makefile recipes still use POSIX tools as build plumbing; Sayanox feature
  logic, fixtures, protocol checks and assertions live in `.sa`.
* The legacy sed-based `tools/sayanox-lsp.sh` shell server was deleted. The
  supported server is `tools/sayanox_lsp.sa`.
* Python remains an optional dependency only for the local HTTP fixture
  server used by the Sayanox network/crawler test program; this is not a
  language runtime or a tracked script.
* `make test-language-deps` checks the boundary: zero tracked `.sh` files,
  static Makefile checks, and a PATH shim that makes bash/awk/sed/python/perl/
  node/ruby fail while the selected language-dependency tests are re-run.

## Sayanox tools built and tested

- `tools/sxfmt.sa` is a conservative formatter written in Sayanox. The
  maintained `gen2` compiler builds it with `make sxfmt`; `make test-sxfmt`
  checks brace-aware indentation, strings/comments, final newlines and
  idempotence. It changes whitespace only; it is not yet a parser-backed
  formatter.
- `tools/sxpkg.sa` implements local `init`, `add`, `list`, `remove`, `seed`,
  `search` and `info` for project locks and the local registry. The shell
  entrypoint delegates these commands to the Sayanox binary. `make sxpkg`
  builds it and `make test-sxpkg` covers the command path.
- `tools/sayanox_lsp.sa` is the language server (diagnostics, symbols,
  completion, hover, definition, references, workspace symbols, formatting,
  rename, signature help, code actions). `make lsp` builds it.
- `tools/lsp_workspace_test.sa` is the LSP test client. It forks the server
  through the language's own process builtins, so no C harness is left in
  `tools/`.

## Still to port

- The transfer *program* of `sync`/`install`/`fetch`: `curl`, or `wget` when
  there is no curl. Everything around it moved into `tools/sxpkg.sa`, which
  became the whole package tool on 2026-10-22 -- the wrapper, its opt-in
  policy, `SAYANOX_ROOT`, its `cut`/`tr` manifest parsing and its `cp`/`mv`
  staging are gone. The transport stays because
  `tools/sxpkg_transfer_test.sa` installs mock `curl`/`wget` executables on a
  controlled `PATH` and asserts their calls: switching to the `http_get`
  builtin would change the transport subject. This is a documented dependency,
  not an unfinished shell-porting step.
- `selfhost/seed/sxc_seed_min.c` is the small trusted bootstrap compiler, and
  `selfhost/native_aot.c` is the current x86-64 Linux native backend.
- `Makefile` and its inline POSIX-shell recipes orchestrate the initial build
  and regression tests; no tracked `.sh` file remains.

Pulling the remaining C and build-driver logic into Sayanox is the next phase,
recorded in [`ALL_SAYANOX_PHASE.md`](ALL_SAYANOX_PHASE.md); `make all-sayanox`
lists what is left and fails closed.

A fresh source checkout needs an initial executable compiler somewhere in its
bootstrap chain. The practical end state is therefore a small, auditable C
seed plus Sayanox-owned compiler and tool logic — not a claim that source text
runs without any host tools. Replacing the seed/backend is a later milestone,
not a prerequisite for moving ordinary compiler and tool logic into Sayanox.
