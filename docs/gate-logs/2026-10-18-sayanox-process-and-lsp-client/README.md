# 2026-10-18 — removing the last C in `tools/`: process builtins and a Sayanox LSP test client

Cut #7 of the dependency work, on branch `arena/cdeaefb3-sayanox`. Every run
below is on this checkout and every log in this directory is the actual
command output.

## What changed

The language gained a process surface and a filesystem-mutation surface, and
the 127-line C LSP test client was rewritten on top of them:

| new builtin | behaviour |
|---|---|
| `spawn(path)` | `fork` + `execl` with piped stdin/stdout; handle 1-8, `0` on failure |
| `child_send(h, s)` | write `s` to the child's stdin; `1` on success, `0` on failure |
| `child_recv(h, n)` | read up to `n` bytes from the child's stdout, stopping at EOF |
| `child_line(h)` | read one line from the child's stdout, without the newline |
| `child_close(h)` | close the child's stdin, `waitpid`, return the exit status (`-1` if it did not exit normally) |
| `make_dir(path)` | `mkdir(path, 0700)` |
| `make_link(target, path)` | `symlink(target, path)` |
| `remove_path(path)` | `unlink`, falling back to `rmdir` |

`tools/lsp_workspace_test.sa` spawns `tools/sayanox_lsp`, holds the framed
initialize / workspace-symbol / references / overlay / disk-refresh / bad-root
/ file-cap sessions and asserts on every answer. `tools/lsp_workspace_test.c`
was deleted; `tools/` contains no C now.

The port was accepted the same way the IR tool was: the Sayanox client's
stdout was compared byte-for-byte with the C client's stdout on the same
fixture before the C file was removed, and `make test-lsp-workspace` now
builds and runs the Sayanox client.

## Gates (all exit 0)

- `make doctor` — `DOCTOR-OK` (`doctor.log`)
- `make true-selfhost` — `=== TRUE-SELFHOST-MIN-OK ===` (`true-selfhost.log`)
- `make gen3` — `=== GEN3-OK ===`, gen3 and gen4 byte-identical (`gen3.log`)
- `make native-test` — `=== NATIVE-TEST-OK ===` (`native-test.log`)
- `make test-proc-builtins` — new gate: a framed child session (two requests,
  two answers, clean exit), `make_dir` / `make_link` / `remove_path`, and every
  `child_*` builtin against a handle that was never spawned
  (`proc-builtins.log`)
- `make test-path-builtins` — unchanged and still green (`path-builtins.log`)
- `make test-exit-builtin` — green (`exit-builtin.log`)
- `make test-lsp-workspace` — green with the Sayanox client
  (`lsp-workspace.log`)
- `make test-lsp-robust`, `make test-lsp-unicode` — green
  (`lsp-robust.log`, `lsp-unicode.log`)
- `make test-language-deps` — green (`language-deps.log`)
- `make test-doc-claims` — green (`doc-claims.log`)

Expected non-success, kept as evidence rather than hidden:

- `make all-sayanox` — still **fails on purpose** (`all-sayanox.log`). The
  inventory it prints lost its `lsp-test-client` row.

## Two bugs found and fixed while porting, not papered over

1. `child_recv` originally did a single `read()`. The language server writes a
   frame in four `write_out` calls plus a flush, so a large answer can arrive
   in several pipe segments and a single read returns a short body — the
   128-file cap assertion failed because the response was truncated. The
   runtime now loops until `n` bytes or EOF, which is what the C client's
   `fread` did.
2. The first port of the test client kept its checks inside a typed function,
   which seed-min rejects before it ever reaches the unknown-builtin refusal.
   The gate therefore pins seed-min's refusal with the same small fixture
   pattern `test-exit-builtin` uses.

## Honest limits

- A child that stays alive but silent blocks the caller, exactly as the C
  client's blocking `fread` did. There is no timeout builtin.
- `child_recv` returns text, so an embedded NUL byte ends the string early;
  the language server never emits one, and the limit is documented in
  `docs/BUILTINS.md`.
- `SIGPIPE` is ignored by the runtime so a write to a dead child fails with
  `0` instead of killing the caller.
- The Sayanox dialect accepts `+` between strings only on the right-hand side
  of an assignment, and rejects a string literal that mixes braces with
  escaped quotes inside a `when` condition. The test client works around both
  deliberately (values are built into variables; JSON quotes come from
  `chr(34)`), and both workarounds are commented in the source.
