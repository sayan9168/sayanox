# 2026-10-18 — the package tool's file logic moves into Sayanox

Cut #9 of the dependency work, on branch `arena/cdeaefb3-sayanox`. Every run
below is on this checkout and every log in this directory is the actual
command output.

## What changed

`tools/sxpkg.sh` used to carry `publish`, `install-local`'s folder loop and the
local-registry halves of `sync` and `fetch` in `grep` / `cut` / `tr` / `cp` /
`mkdir` / `rm`. All of that is Sayanox now, in `tools/sxpkg.sa`.

| file | before | after | what moved |
|---|---:|---:|---|
| `tools/sxpkg.sa` | 1,149 lines | 1,786 lines | `publish`, `install-local`, `sync-local`, `fetch-local`, the `seed` folders, and `ensure_dir` / `rm_tree` / `copy_tree` |
| `tools/sxpkg.sh` | 345 lines | 362 lines | those five commands became one-line delegations; the shell kept the http(s) transport, the opt-in policy and the dispatch |

Nothing new was added to the compiler: `ensure_dir`, `rm_tree` and `copy_tree`
are ordinary `make` functions over the builtins cut #7 already added
(`make_dir`, `path_kind`, `read_dir`, `remove_path`), and `toml_field` reads a
`key = "value"` line the way `grep '^key' | cut -d= -f2- | tr -d '" '` did.

| new command | behaviour |
|---|---|
| `publish` | reads `name`/`version` out of `sx.toml`, writes `pkg.meta` (with the `sum=` of the copied `main.sa`, exactly as the seed writes it) and `main.sa` into `.sayanox/registry/<name>/`, adds one `<name>=<version>` line to `INDEX` unless it is there, and reports once |
| `install-local [dir]` | preflights every locked name, creates `.sayanox/registry/<n>/` and `.sayanox/pkgs/<n>/`, runs the install logic against a local registry directory, exits 1 on an unresolvable lock, an unsafe name or a missing `sx.lock` |
| `sync-local <registry>` | writes `INDEX` only after every name in it has passed `check-name`, copies each indexed package, falls back to `seed` when there is no index to read |
| `fetch-local <src> <name> <display>` | reads a local source, records the `sum=`, copies to both `.sayanox/registry/<n>/` and `.sayanox/pkgs/<n>/`, appends `<n>=0.0.0` to `sx.lock`, and removes both copies and restores the lock if any write fails |
| `ensure-dir` / `rm-tree` / `copy-tree` | `mkdir -p`, `rm -rf` and `cp -r src/. dst/` |

## Gates (all exit 0)

The whole suite below was one `make` invocation, so `gen2` was rebuilt once and
every gate ran against the same binaries; `full-suite.log` is that run in full
(2,521 lines, `SUITE_EXIT=0`), and each gate's slice is also kept separately.
`gen3` was run afterwards against the same `gen2` (`gen3.log`), which ends with `=== GEN3-OK ===` and `[OK] byte-identical gen3 == gen4`.

- `make doctor` — `DOCTOR-OK` (`doctor.log`)
- `make true-selfhost-min` — `=== TRUE-SELFHOST-MIN-OK ===`
  (`true-selfhost.log`); the new gate is inside it through the `test-stage2`
  chain. `gen3 == gen4` is still byte-identical; that gate ran separately
  against the same `gen2` (`gen3.log`, ending in `=== GEN3-OK ===` and
  `[OK] byte-identical gen3 == gen4`)
- `make native-test` — `=== NATIVE-TEST-OK ===` (`native-test.log`)
- `make test-native-primitives` — `[OK] native primitives: ...`
  (`native-primitives.log`)
- The five sxpkg gates, **unchanged and still green** — this is the acceptance
  test for the port, because a behavioural port must not change what they pin:
  - `make test-sxpkg` — `[OK] Sayanox package tool: init/add/update/list/remove`
    (`test-sxpkg.log`)
  - `make test-sxpkg-wrapper` — `[OK] sxpkg.sh delegates local commands to
    Sayanox` (`test-sxpkg-wrapper.log`)
  - `make test-sxpkg-polish` — `[OK] sxpkg offline polish: add note,
    verify/install-local exit codes, unknown command rc 2, publish once`
    (`test-sxpkg-polish.log`)
  - `make test-sxpkg-online-local` — `[OK] sxpkg online install (file://
    registry): good accepted, tampered rejected and removed, missing leaves no
    partial file` (`test-sxpkg-online-local.log`)
  - `make test-sxpkg-transfer-hardening` — `[OK] sxpkg hardening: no-opt-in/name
    refusal before transport; interrupted fetch rollback; curl/wget mocked
    success; checksum verification/tamper; overwrite refusal; rooted relative
    local fetch; cached install without INDEX; no DNS`
    (`test-sxpkg-transfer-hardening.log`)
  - `make test-sxpkg-online-optin` — opt-in refusal unchanged
    (`test-sxpkg-online-optin.log`)
- `make test-sxpkg-sayanox-logic` — the new gate
  (`test-sxpkg-sayanox-logic.log`): `[OK] sxpkg in Sayanox: publish,
  install-local, local sync/fetch, rollback, and the folder primitives`. It
  pins publish's files and its single report, install-local's folders and its
  three exit codes, sync's index preflight and seed fallback, fetch's lock pin
  and full rollback, the three folder primitives, and the two compiler traps
  below.
- `make test-proc-builtins`, `make test-path-builtins`,
  `make test-exit-builtin`, `make test-language-deps`, `make test-doc-claims`
  — unchanged and still green (`proc-builtins.log`, `path-builtins.log`,
  `exit-builtin.log`, `language-deps.log`, `doc-claims.log`)

Expected non-success, kept as evidence rather than hidden:

- `make all-sayanox` — still **fails on purpose** (`all-sayanox.log`). The
  inventory it prints now reads 274 `.sa` files and still lists the seed, the
  native backend and the build driver.

## Honest limits

- **The http(s) transport stays in the shell, and it is a language blocker
  rather than a missing step.** `spawn(path)` takes no arguments, so Sayanox
  cannot launch `curl -fsSL --connect-timeout 10 --max-time 60 <url> -o
  <part>`. `selfhost/test_sxpkg_transfer_hardening.sh` mocks `curl`/`wget`
  through `PATH` and asserts `$MOCK_CALLS` contains them, so switching to
  `http_get` would break a gate that must stay unchanged. `docs/SXPKG_ONLINE.md`
  records the same boundary.
- **A second compiler trap was found while porting and is documented, not
  hidden.** The compiler's signature pre-pass does not understand `//`
  comments — the comment-tracking branch in that loop is dead code (`fscm` is
  never set to 1) — so a double quote inside a comment toggles string mode. A
  comment with an *odd* number of double quotes makes the pre-pass treat the
  rest of the file as one string literal, every later `make` is missed, and
  each of those functions falls back to the raw parameter parse, which reads
  `a: str` as two untyped parameters. It was found the loud way: the generated
  C did not compile (`static double rm_tree(double path, double str)` plus
  `#error sayanox-min: unknown function: rm_tree`). `make
  test-sxpkg-sayanox-logic` pins both halves — a fixture whose comment carries
  two quotes must still compile to `double a, char *b`, and `tools/sxpkg.c`
  must not contain the mangled `, double str,` signature.
- **A third bug, mine, was caught by the same gate's shape rather than by a
  gate.** `toml_field` first used the "set the loop bound to stop" idiom and
  clobbered the position it was supposed to remember, so `publish` read the
  name as `=pol-pkg\nversion=0.1.0`. It is fixed with explicit stop flags, and
  the publish half of the new gate pins the values it must produce.
- `install-local` now also creates `.sayanox/pkgs/<name>/`, where the shell
  only made `.sayanox/pkgs` itself. It still copies into the registry only,
  exactly as before.
- A local `sync` that finds no `INDEX` reports `sxpkg: sync failed; using local
  seed` instead of `online sync failed`, and the fallback is the same `seed`
  command.
- The http(s) halves of `sync`, `install` and `fetch` are unchanged shell,
  including the `.fetch.XXXXXX` staging directory and its `trap` rollback.
  `tools/sxpkg.sh` still uses `cut` to parse the binary's own `sum` output and
  `cp`/`mv`/`mktemp` to move a downloaded file; the package commands
  themselves no longer call `grep`, `cut`, `tr`, `cp`, `mkdir` or `rm`.
- Phase C is not finished and no gate claims it is: `make all-sayanox` still
  exits 1, and `docs/ALL_SAYANOX_PHASE.md` records the transport as a
  documented exception.
