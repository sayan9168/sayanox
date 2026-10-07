# Sayanox-owned tooling: migration status

The project goal is to move compiler and developer-tool **logic** into
Sayanox. That migration is not complete; do not read the repository as claiming
that every tool is already a `.sa` program.

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

## Still to port

- Online sync/install/publish/fetch and package-directory management remain in
  `tools/sxpkg.sh`; Sayanox still needs filesystem-directory and network APIs.
- `tools/sayanox-lsp.sh` is still a shell implementation; the language/runtime
  does not yet provide the stdin and JSON facilities needed for an equivalent
  `.sa` server.
- `selfhost/seed/sxc_seed_min.c` is the small trusted bootstrap compiler, and
  `selfhost/native_aot.c` is the current x86-64 Linux native backend.
- `Makefile` and its POSIX-shell recipes orchestrate the initial build and
  regression tests.

A fresh source checkout needs an initial executable compiler somewhere in its
bootstrap chain. The practical end state is therefore a small, auditable C
seed plus Sayanox-owned compiler and tool logic—not a claim that source text
runs without any host tools. Replacing the seed/backend is a later milestone,
not a prerequisite for moving ordinary compiler and tool logic into Sayanox.
