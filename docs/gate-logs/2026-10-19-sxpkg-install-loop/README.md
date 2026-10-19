# 2026-10-19 — `install`'s offline half moves into Sayanox

Cut #11 of the dependency work, on branch `arena/cdeaefb3-sayanox`. Every run
below is on this checkout and every log in this directory is the actual
command output.

## What changed

`tools/sxpkg.sh install` was the last command in the wrapper that still made
package decisions in the shell. It walked `sx.lock` line by line, decided
which packages were missing, built the paths, copied the files and wrote the
report — while every other command had already become a one-line delegation.

Three commands in `tools/sxpkg.sa` take that over:

| new command | what it does |
|---|---|
| `check-lock [file]` | walks a lock or an index file and refuses the first unsafe name with `sxpkg: refusing unsafe package name '<name>'`, exit 1. Replaces the shell's `preflight_names`, which spawned one `check-name` child per line |
| `need-fetch` | prints the locked packages whose registry copy is incomplete, one per line. A package counts as present only when both `pkg.meta` and `main.sa` are there |
| `install-cached [pkgdir]` | copies every locked package that now has a complete registry copy into `pkgdir`, reports the ones that do not, and refuses to build a path from an unsafe name |

The wrapper's `install` becomes: preflight (Sayanox) → fetch what `need-fetch`
named (shell, the only part that touches the network) → copy and report
(Sayanox) → verify and roll back (Sayanox). Its `while IFS='=' read` loop and
its inline `case "$n" in */*|*..*)` guard are gone; `sync`'s http branch calls
`check-lock` instead of `preflight_names`.

| file | before | after |
|---|---:|---:|
| `tools/sxpkg.sa` | 1,788 lines | 1,898 lines |
| `tools/sxpkg.sh` | 363 lines | 347 lines |
| `Makefile` | 4,828 lines | 4,860 lines |

## Gates (all exit 0)

The whole suite below was one `make` invocation, so `gen2` was rebuilt once and
every gate ran against the same binaries; `full-suite.log` is that run in full
and each gate's slice is also kept separately. `gen3` was run afterwards
against the same `gen2` (`gen3.log`), ending in `=== GEN3-OK ===` and
`[OK] byte-identical gen3 == gen4`.

- `make doctor` — `DOCTOR-OK` (`doctor.log`)
- `make true-selfhost-min` — `=== TRUE-SELFHOST-MIN-OK ===`
  (`true-selfhost.log`)
- `make native-test` — `=== NATIVE-TEST-OK ===` (`native-test.log`)
- `make test-native-primitives` — `[OK] native primitives: ...`
  (`native-primitives.log`)
- `make test-comment-quotes` — cut #10's gate, still green
  (`comment-quotes.log`)
- **The sxpkg gates, unchanged and still green** — this is the acceptance test
  for the port, because a behavioural port must not change what they pin:
  `test-sxpkg.log`, `test-sxpkg-wrapper.log`, `test-sxpkg-polish.log`,
  `test-sxpkg-online-local.log`, `test-sxpkg-transfer-hardening.log`,
  `test-sxpkg-online-optin.log`, plus `test-pkgs.log` and
  `test-pkg-errors.log`
- `make test-sxpkg-sayanox-logic` — extended, not weakened
  (`test-sxpkg-sayanox-logic.log`). The new section pins the three commands
  directly:
  - `check-lock` refuses a final line with **no trailing newline**, refuses an
    unsafe name, and names it in its report;
  - `need-fetch` names exactly the locked packages with no complete copy
    (`strings`, and not `hello`, which the seed wrote);
  - `install-cached` prints `sxpkg: installed hello -> icdir/hello` and
    `sxpkg: missing strings in registry`, copies the complete package, and
    refuses an unsafe name even when called directly.
- `make test-proc-builtins`, `make test-path-builtins`,
  `make test-exit-builtin`, `make test-language-deps`, `make test-doc-claims`
  — unchanged and still green (`proc-builtins.log`, `path-builtins.log`,
  `exit-builtin.log`, `language-deps.log`, `doc-claims.log`)

Expected non-success, kept as evidence rather than hidden:

- `make all-sayanox` — still **fails on purpose** (`all-sayanox.log`). The
  inventory it prints now reads 279 `.sa` files, 4,860 Makefile lines and
  still lists the seed, the native backend and the build driver.

## Honest limits

- **One visible string changed.** `sxpkg: installed <name> -> <path>` now
  prints the project's absolute pkgs path instead of `$ROOT/.sayanox/pkgs`,
  because the binary runs with the project root as its working directory and
  an absolute path is the only form that is valid from there. No gate and no
  document pinned the old relative form; `install-local`'s
  `sxpkg: installed <name> <version>` is a different message and is unchanged.
- **The message order for a multi-package install changed.** The wrapper used
  to interleave "fetch this one, install this one" per package; it now fetches
  everything `need-fetch` named and then installs. With one locked package —
  which is what every gate uses — the order is identical, and the gates only
  assert exit status, `verify ok` and the absence of leftovers, so nothing
  pinned the interleaving.
- **`path_kind` uses `lstat`, so a symlinked `main.sa` reads as "missing"**
  where the shell's `[ -f ]` followed the link. No gate or fixture puts a
  symlink in the registry, and `copy_tree` already had the same `lstat`
  behaviour.
- **The http(s) halves of `sync`, `install` and `fetch` are still shell**, as
  is the `need_online` opt-in policy: Sayanox has no `getenv`, and
  `spawn(path)` takes no argv so it cannot launch curl with a URL. That
  boundary is unchanged by this cut and is still recorded in
  `docs/SXPKG_ONLINE.md` and `docs/ALL_SAYANOX_PHASE.md`.
- **A recipe that runs a command expected to exit non-zero must swallow the
  status.** The first version of the new gate section let `check-lock`'s exit
  1 abort the recipe; it now ends the line with `|| true` and asserts on the
  output and on the exit status separately. Worth writing down because the
  failure looked like it came from an unrelated line of the same target.
