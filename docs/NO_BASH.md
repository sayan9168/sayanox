# Sayanox-owned tooling: migration status

The project goal is to move compiler and developer-tool **logic** into
Sayanox. That migration is not complete; do not read the repository as claiming
that every tool is already a `.sa` program.

## No bash, awk or sed on the maintained paths (2026-10-17)

* All tracked shebang scripts are `#!/bin/sh`. The six former bash scripts —
  `selfhost/sx`, `restore_stage2.sh`, `restore_sxc_full.sh`,
  `restore_compiler_min.sh`, `pack_compiler_min.sh` and `lang_quality.sh` —
  were ported; `pipefail`, `[[ ]]`, arrays, `local` and process substitution
  are gone. Four of the six were then deleted on 2026-10-21 (`selfhost/sx`,
  `restore_stage2.sh`, `restore_sxc_full.sh`, `lang_quality.sh`) because they
  drove a Stage-2 host that does not exist.
* The LSP build needs no binder at all since 2026-10-17: the folder index is
  Sayanox (`read_dir`/`path_kind`/`path_size`/`path_real`), so both
  `tools/lsp_workspace_bind.sa` (itself a Sayanox replacement for the old awk
  binder) and the C header it injected were deleted.
* The offline packer chunks with `split -b 1100`; test recipes extract lines
  with POSIX `read`; the native IR-log checks use `grep`/`cut`/`sort`/`paste`;
  the emit-seam region uses `head`/`tail`; `tools/sxpkg.sh` uses `cut`/`tr`
  only to parse the Sayanox binary's own `sum` output inside its http(s)
  transport, and `cp`/`mv`/`mktemp` only to move a downloaded file — the
  package commands themselves (`publish`, `install-local`, the local branches
  of `sync` and `fetch`) no longer call `grep`, `cut`, `tr`, `cp`, `mkdir` or
  `rm` at all.
* The legacy sed-based `tools/sayanox-lsp.sh` shell server was deleted. The
  supported server is `tools/sayanox_lsp.sa`.
* Python was removed from the restore scripts (a dead installer branch and a
  base64 heredoc). It remains only in the optional HTTP/crawler test servers,
  which are not bootstrap prerequisites.
* `make test-language-deps` checks the boundary: a static scan plus a PATH shim
  that makes bash/awk/sed/python/perl/node/ruby fail and logs any invocation
  while the affected paths are re-run.

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

- The http(s) transport of `sync`/`install`/`fetch` remains in
  `tools/sxpkg.sh`. The file side of those commands, `publish`,
  `install-local`, the seed folders and every folder/copy operation moved to
  `tools/sxpkg.sa` on 2026-10-18 (`make test-sxpkg-sayanox-logic`). The
  transport is blocked on the language rather than on willingness:
  `spawn(path)` takes no arguments, so Sayanox cannot launch
  `curl -fsSL --connect-timeout 10 --max-time 60 <url> -o <part>`, and
  `selfhost/test_sxpkg_transfer_hardening.sh` mocks `curl`/`wget` through
  `PATH` and asserts `$MOCK_CALLS` contains them, so switching to `http_get`
  would break a gate that must stay unchanged. This is a documented
  exception, not an unfinished step.
- `selfhost/seed/sxc_seed_min.c` is the small trusted bootstrap compiler, and
  `selfhost/native_aot.c` is the current x86-64 Linux native backend.
- `Makefile` and its POSIX-shell recipes orchestrate the initial build and
  regression tests.

Pulling the remaining C and shell pieces into Sayanox is the next phase,
recorded in [`ALL_SAYANOX_PHASE.md`](ALL_SAYANOX_PHASE.md); `make all-sayanox`
lists what is left and fails closed.

A fresh source checkout needs an initial executable compiler somewhere in its
bootstrap chain. The practical end state is therefore a small, auditable C
seed plus Sayanox-owned compiler and tool logic — not a claim that source text
runs without any host tools. Replacing the seed/backend is a later milestone,
not a prerequisite for moving ordinary compiler and tool logic into Sayanox.
