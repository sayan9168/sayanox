# 2026-10-22 — the package tool is one Sayanox program

`tools/sxpkg.sh` is deleted. `tools/sxpkg.sa` is the whole package tool:
2,565 lines that answer every command the wrapper answered, read the three
environment variables it read, build every path from `SAYANOX_ROOT`, apply the
online opt-in policy, stage downloads, verify checksums, roll back, and set the
exit statuses. The only program it still starts is the transfer itself.

## 1. The builtin that unblocked it: `getenv`

`run_command(cmd)` (2026-10-21) removed the argv obstacle — a Sayanox program
can now launch `curl -fsSL --connect-timeout 10 --max-time 60 <url> -o <part>`.
What remained was smaller and more annoying: the wrapper existed to read
`SAYANOX_ROOT`, `SAYANOX_REGISTRY` and `SAYANOX_ONLINE`, and to `cd` into the
project before running the binary.

`getenv(name)` answers the first half: it gives an environment variable's value
and `""` when it is not set, which is what every call site wanted ("not given"
is a value, not an error). The second half needed no builtin: there is no
`chdir`, so the tool builds every path through a root instead —
`lock_path`, `manifest_path`, `registry_path`, `index_path` and `pkg_path` are
`rooted(root, ...)`, and so are the registry source of `install` /
`install-local` / `deps` and the destination of every write.

`getenv` is wired through the same sites as the other builtins: the `returns`
and `signatures` tables, both builtin-name lists, the argument rewriter, the
`fk` classifier and emitter in both passes (fk 44, numeric 43), the nested-call
operand and argument-word maps, the typed-signature call table, the in-call
name list, the string-kind inference lists, and the runtime blob. seed-min
refuses it like every other late builtin; the native backend refuses it through
its existing `unknown builtin` path.

## 2. What moved, and what did not

| wrapper job | now |
|---|---|
| `SAYANOX_ROOT` + `cd "$ROOT"` | `getenv` + `rooted()` on every path |
| `SAYANOX_ONLINE` / `--online` | `getenv` + the flag shift in argv |
| `need_online()` refusal | `need_online(target, optin)`, same words |
| `command -v curl` / `wget` | `path_find("curl")` — a PATH scan in Sayanox |
| `curl … -o part`, `mv part dest` | `run_command` + `read_file`/`write_file`/`remove_path` |
| `mktemp -d` staging for `fetch` | a fixed `.fetch.stage` inside the registry |
| `cut -d' ' -f3` on `sxpkg sum` | the sum is computed in-process |
| `sync`'s online branch | a Sayanox loop: INDEX, check every name, then one `pkg.meta`/`main.sa` per package |
| `install`'s fetch loop | the same: preflight, fetch only what is missing, copy, verify, roll back |
| `fetch`'s remote branch | download to the staging file, then the existing `fetch-local` path |
| `checked` (rc from FAILED/DEP output) | the tool sets its own exit status |
| `cd` failure on a bad root | `sxpkg: could not run <cmd> in project <root>`, exit 1 |

What did **not** move: the transport program. `test-sxpkg-transfer-hardening`
mocks `curl`/`wget` through `PATH` and asserts the mock was called, which is a
statement about *which* program is allowed to open a socket. Replacing it with
the `http_get` builtin would delete the test's subject, so curl/wget stays and
the test now exercises the same behaviour through the binary instead of the
shell. That decision is recorded in `docs/NO_BASH.md`, not hidden here.

## 3. Two bugs the port found in my own new code

Both were caught by compiled output or by a gate, and both are the kind that
would have been invisible in a diff review:

* `--online` was silently ignored because the *old* argument parsing block was
  still in the file after the new one. The generated C had two
  `command = sx_arg(...)` chains and the second one won. Looking at the C, not
  at the source, is what found it.
* The wrapper's `cd "$ROOT"` failure was a behaviour, and `test-pkg-errors`
  pins it. With no `cd`, a root that is a regular file must fail the same way,
  in the same words — so the tool now checks `path_kind(root)` at startup.

## 4. Honest status after this step

`make all-sayanox` still exits 1, and should. What is left is not "shell glue
we have not got to":

* `selfhost/seed/sxc_seed_min.c` (2,035 lines) — the bootstrap seed.
* `selfhost/native_aot.c` (4,498 lines) — the native backend.
* `Makefile` (make) and the `sh` test drivers.

The package tool used to be on that list. It is not any more, and the reason it
is not is a builtin pair (`getenv` + `run_command`) plus the decision to keep
the transport as an external program.
