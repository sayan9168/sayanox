# sxpkg online: a thin design

Status: **implemented, network opt-in; audited 2026-10-16.** Lock/metadata and
checksum logic remain `.sa`; filesystem/network operations remain thin shell.
`test-sxpkg-online-local` copies from a `file://` registry using POSIX `cp`,
not curl/wget, and checks good/tampered/missing content plus cleanup.
`test-sxpkg-online-optin` tests refusal without permission and uses a checked
failing shell transport stub for the two opted-in legs. No DNS/network access
occurs in either gate; they no longer skip for missing network clients.
Real remote transfers still require explicit opt-in and optional curl/wget.
No stronger integrity mechanism was added: `sum=` is not cryptography.

## Principles

1. **The network is opt-in and lives outside the bootstrap.** Every target in
   `make doctor`, `true-selfhost`, `gen3` and `native-test` is offline. Online
   commands are shell-only (`curl`, falling back to `wget`) and no gate performs
   a real transfer. Since 2026-10-13 permission is explicit: `sync`, `install`
   (when it has to fetch) and `fetch` **refuse** unless the caller sets
   `SAYANOX_ONLINE=1` or uses `sxpkg --online <command>`. `SAYANOX_REGISTRY`
   says *where* a transfer goes; it is not permission to transfer. A `file://`
   URL or a plain local path is not the network and never asks. The refusal
   happens before any transfer starts, prints the opt-in and the offline
   alternatives, exits 1, and leaves no `.part` file and no package directory
   behind.
2. **The Sayanox binary never touches the network.** Online transfer needs
   sockets and TLS, and the language has neither. The binary does the local
   work: the lock file, dependency closure, checksums, and copies. The shell
   does the transfer.
3. **Offline stays first-class.** Every online command has an offline path that
   works from a local registry directory. `install-local` and `seed` never
   fetch.
4. **Integrity is a checksum, not a signature.** `pkg.meta` carries `sum=`, the
   value of `pkgsum` over `main.sa` (a 31-multiplier hash mod 1000000007). It
   detects accidental edits. It is **not** a cryptographic hash and does not
   prove who published a package. The design does not claim otherwise.

   *Updated 2026-10-22.* `pkg.meta` now also carries `sha256=` (a real
   cryptographic digest of `main.sa`, from `stdlib/crypto.sa`) and, after
   `sxpkg sign`, `signer=`/`sig=` (HMAC-SHA256 over name, version and digest).
   `sum=` is unchanged and still checked, so old registries keep verifying.
   The signature is **symmetric**: checking it needs the same secret that
   signed it, so it protects a tree you share a key with, not a download from
   a stranger. See [REGISTRY.md](REGISTRY.md) for the exact fields, commands
   and statuses.

## Current surface (what the code does)

| Command | Where it runs | What it does | Network |
|---|---|---|---|
| `init`, `add`, `list`, `remove`, `deps`, `search`, `info`, `verify`, `sum` | Sayanox binary (`tools/sxpkg.sa`) | local lock file and local registry | no |
| `seed` | Sayanox binary | writes the sample registry (`hello` and `math`, the two packages the binary knows) | no |
| `install-local [dir]` | Sayanox binary | preflights the lock, creates `.sayanox/registry/<n>/` and `.sayanox/pkgs/<n>/`, copies the lock closure out of a local registry dir, sum-checked; exits 1 on an unresolvable lock, an unsafe name or a missing `sx.lock` | no |
| `sync` | shell for http(s), Sayanox for a local registry | http(s): downloads `INDEX` and each indexed package's `pkg.meta`/`main.sa` from `$SAYANOX_REGISTRY`. A `file://` URL or a plain path goes to the Sayanox `sync-local`, which writes `INDEX` only after every name in it has passed `check-name` and falls back to `seed` when there is no index to read | **yes** for http(s) — opt-in (curl/wget); a local registry needs no opt-in |
| `install` | shell | uses cached locked packages without requiring INDEX; fetches missing entries | only when missing, opt-in |
| `fetch <url> [name]` | shell for http(s), Sayanox for a local source | http(s): downloads one `main.sa` into a `.fetch.XXXXXX` staging directory and commits it with a `trap` rollback. A `file://` URL or a plain path goes to the Sayanox `fetch-local`, which reads the source, records the `sum=`, copies to both `.sayanox/registry/<n>/` and `.sayanox/pkgs/<n>/`, appends `<n>=0.0.0` to `sx.lock`, and removes both copies and restores the lock if any write fails. Both write `pkg.meta` **with the `sum=` of the fetched bytes** and lock it as `0.0.0` | **yes** for http(s); a local source needs no opt-in |
| `publish` | Sayanox binary | reads `name`/`version` out of `sx.toml`, writes `pkg.meta` (with the `sum=` of the copied `main.sa`, exactly as the seed writes it) and `main.sa` into `.sayanox/registry/<name>/`, adds one `<name>=<version>` line to `INDEX` unless it is there, and prints "commit registry/<name> to go online" | no (it never uploads) |

`SAYANOX_REGISTRY` overrides the default online index, which is the raw
`registry/` directory of the GitHub repository.

## Shell/Sayanox `pkg.meta` consistency (2026-10-13)

The shell `publish` and `fetch` used to write `pkg.meta` **without** `sum=`,
while the Sayanox implementation always writes it and `verify` checks it — a
shell-published package could therefore fail (or silently skip) the very
check the registry story rests on. Both shell commands now record
`sum=` (via `sxpkg sum`, the same `pkgsum`: `h = (h*31 + byte) mod
1000000007`) whenever a `main.sa` is present, so a shell-published or
shell-fetched package verifies the same way as a Sayanox-seeded one.
`pkgsum` is a change detector, **not** a cryptographic hash: a mismatch proves the bytes changed, but a matching value does not
prove equality or authorship (see the table of deliberately-not-done
items below).

## Contract for the online commands

### Index

* `INDEX` is a plain text file: one `name=version` per line. Lines starting
  with `#` are comments. Nothing else is allowed.
* `sync` replaces `.sayanox/registry/INDEX` only after a successful download.
  On failure it falls back to the local seed and says so.

### Package layout

* `<registry>/<name>/pkg.meta`: `name=`, `version=`, optional `desc=`,
  `deps=name@version,...` (exact pins), `sum=`.
* `<registry>/<name>/main.sa`: the package source. `use` splices it.

### Transfer rules (the shell's job)

Since 2026-10-18 the shell's job is exactly the http(s) transport and the
opt-in policy. Everything else — publish, install-local, the local-registry
branches of `sync` and `fetch`, folder creation and deletion — is
`tools/sxpkg.sa`. The boundary is a language limit, not a preference:
`spawn(path)` takes no arguments, so Sayanox cannot launch
`curl -fsSL --connect-timeout 10 --max-time 60 <url> -o <part>`, and
`selfhost/test_sxpkg_transfer_hardening.sh` mocks `curl`/`wget` through `PATH`
and asserts `$MOCK_CALLS` contains them, so the transport has to stay in the
shell. `ensure_dir`, `rm_tree` and `copy_tree` in `tools/sxpkg.sa` are ordinary
functions over `make_dir`/`read_dir`/`remove_path`, which is why the wrapper no
longer calls `mkdir`, `rm`, `cp`, `grep`, `cut` or `tr` in these paths.
Gate: `make test-sxpkg-sayanox-logic`.

* A download that fails leaves no partial file behind. `download()` writes to
  `<dest>.part` and renames it only on success, so a failed transfer leaves no
  `main.sa` behind (tested by `test-sxpkg-online-local`).
* A download is bounded: `curl -fsSL --connect-timeout 10 --max-time 60`, or
  `wget -q --timeout=10 --tries=1`. A host that accepts the connection and then
  goes quiet cannot hang a build or a gate.
* A download is refused before it starts unless the run is opted in
  (`SAYANOX_ONLINE=1` / `--online`), except for `file://` and local paths
  (tested by `test-sxpkg-online-optin`).
* `install` decides per package: a locked package whose `pkg.meta` **and**
  `main.sa` are already in `.sayanox/registry/` is copied and verified with no
  opt-in and no transfer, so an offline checkout keeps working against a remote
  registry URL. Only a genuinely missing package asks for permission.
* A transfer that fails `verify` is removed: `install` deletes the packages it
  fetched in that run, from the registry and from the project, and exits 1.
  Package names containing `/` or `..` are refused before any file is touched.
* A transfer is accepted only when the Sayanox binary's `verify` passes on the
  result. The sum check, not the transport, is the acceptance test.
* The wrapper has no credential store or publisher-authentication protocol.
  Optional transport clients retain their own environment/configuration
  behavior; this is not an isolated or authenticated transport sandbox.

### Verification

`verify` checks every locked package against the local registry copy: the
version must match `sx.lock`, and `pkgsum(main.sa)` must equal `sum=` in
`pkg.meta`. Dependency-only packages are checked the same way. A mismatch is
reported as `MISMATCH` and the wrapper exits 1 (see `test-sxpkg-polish`).
The online path is tested against a local `file://` registry by
`make test-sxpkg-online-local` (offline, required by true-selfhost; no curl dependency).

## Missing (and why it is not in this pass)

| Gap | Why it matters | Why not now |
|---|---|---|
| ~~A cryptographic hash~~ **done 2026-10-22** | `pkgsum` is a 31-multiplier hash; collisions are easy to make on purpose (`make test-sxpkg-crypto` builds one) | `sha256=` was added *beside* `sum=` instead of replacing it, so no existing `sum=` or fixture changed |
| ~~Signed `pkg.meta`~~ **partly done 2026-10-22** | Without a signature a compromised host could publish a matching `sum=` | `sxpkg sign`/`authenticate` add a keyed (HMAC) signature, which needs a shared secret; a **public-key** signature and a signed *index* still need a key distribution and trust policy, which is a product decision |
| Version ranges | `deps=` uses exact pins only, so resolution is trivial and reproducible | ranges need a solver; exact pins are the honest first step |
| `publish` upload | Publishing is a commit to this repository today; `publish` writes `pkg.meta`/`main.sa` into the local registry and `INDEX` and says so. `SAYANOX_ONLINE=1` deliberately changes nothing here | an upload API is a server design, not a client one, and an unreviewed upload path would defeat the registry's only trust mechanism (a commit others can read) |
| Exit codes from the Sayanox binary | The shell wrapper derives them from `FAILED`/`DEP` lines | the language has no exit builtin; adding one changes the compiler bootstrap |

## What must not be claimed

* That sxpkg is a secure package manager. It is a checksummed local lock file
  with an optional shell transfer -- now with a cryptographic digest and an
  optional keyed signature, which is not the same thing as a trust model.
* That online packages are verified by a *public-key* signature. They are not:
  `sxpkg authenticate` checks an HMAC with a secret both sides already share,
  and a package nobody signed reports `UNSIGNED`.
* That the bootstrap needs, or tests, the network. It does not: the two targets
  that cover this path use a `file://` registry and `.invalid` host names.
* That a command "works offline" only when it never mentions a URL. `install`
  with a remote `SAYANOX_REGISTRY` and a complete local registry is an offline
  command; the same command with a missing package is not, and says so.

## Transfer hardening and deterministic success paths (2026-10-16)

The previous documentation said `fetch` wrote `sum=`; the audited code did
**not**. This increment implements that behavior rather than repeating the
claim. A fetch downloads into a private staging directory, obtains the checksum
from the `.sa` binary's `sum` command, writes metadata and prepares the project
copy/lock before committing. Download failure removes staging and leaves no
package or lock entry. Existing cache directories, installed copies or lock
pins are refused rather than overwritten. A normal commit error attempts to
roll back newly owned package directories. This is not a crash-proof,
concurrent multi-file transaction: no locking, fsync or SIGKILL/power-loss
recovery is claimed.

Fetch records the checksum of the bytes it just received -- since 2026-10-22
that is `sum=` *and* `sha256=`, plus `origin=fetch:<url>`. There is still no
trusted expected digest and no publisher identity: this detects later edits,
**not a malicious first download** or substitution. A deliberate collision is
now ruled out for the recorded bytes (SHA-256), but the bytes are still
whatever the host sent. `source=`/`origin=` are provenance notes, not
integrity assertions.

Package-name validation is implemented in `tools/sxpkg.sa` and exposed by the
`check-name` subcommand. The wrapper uses it before fetch/add path construction
and when preflighting install lock entries and downloaded INDEX entries. Names
are nonempty ASCII letters/digits/hyphen/underscore, excluding reserved `name`
and `version`. Dots, slashes, whitespace and traversal components are refused.
An unsafe downloaded index is rejected before replacing the current INDEX.
This preflight is not a comprehensive hostile-registry parser, symlink defense,
dependency graph security audit or all-command filesystem sandbox.

An all-local `install` no longer calls `sync` merely because INDEX is absent:
its lock and complete cached packages suffice. Absolute, `./` and bare-relative
local paths plus `file://` use `cp` without permission or curl/wget. Only
HTTP/HTTPS transfers use the optional clients; unsupported URI schemes are
refused. The wrapper's opt-in and existing timeout behavior are unchanged.

`make test-sxpkg-transfer-hardening`, required by `test-sxpkg-online-optin`,
adds deterministic **successful** curl and wget-only stubs, not just failure
fallbacks. Neither stub has any socket/DNS code. Coverage includes:

* refusal before transport without opt-in and for unsafe fetch names;
* a stub writing partial bytes then failing: lock preserved, staging removed;
* successful opt-in via curl and a PATH with only mocked wget (no real curl);
* fetched metadata sum, copied bytes, verify success and tamper rejection;
* refusing existing package/lock replacement before transport;
* rooted bare-relative local fetch without opt-in;
* unsafe downloaded index preserving the previous INDEX;
* unsafe hand-edited lock rejected by both install paths before transport;
* cached install with no INDEX and a remote registry URL making no transfer;
* no leftover `.part` or fetch staging directories on the tested paths.

The full package suite and four bootstrap gates are recorded in
[2026-10-16 package logs](gate-logs/2026-10-16-packages/). Bootstrap remains
network-free and interpreter-free; stronger integrity, signatures and
provenance are **not** implemented or claimed.

Current empty-source boundary: the `.sa` `sum` command cannot distinguish an
empty file from an unreadable one. Staged fetch therefore refuses an empty
source when it cannot obtain a numeric sum, rather than silently installing
metadata without a checksum. This increment does not redesign that file API.
