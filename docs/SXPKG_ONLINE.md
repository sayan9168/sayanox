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

## Current surface (what the code does)

| Command | Where it runs | What it does | Network |
|---|---|---|---|
| `init`, `add`, `list`, `remove`, `deps`, `search`, `info`, `verify`, `sum` | Sayanox binary (`tools/sxpkg.sa`) | local lock file and local registry | no |
| `seed` | Sayanox binary | writes the sample registry (`hello` and `math`, the two packages the binary knows) | no |
| `install-local [dir]` | shell `mkdir` + Sayanox `install` | copies the lock closure out of a local registry dir, sum-checked | no |
| `sync` | shell | downloads `INDEX` and each indexed package's `pkg.meta`/`main.sa` from `$SAYANOX_REGISTRY` | **yes** — opt-in (curl/wget) |
| `install` | shell | uses cached locked packages without requiring INDEX; fetches missing entries | only when missing, opt-in |
| `fetch <url> [name]` | shell | downloads one `main.sa`, writes `pkg.meta` **with the `sum=` of the fetched bytes**, and locks it as `0.0.0` | **yes** |
| `publish` | shell | writes `pkg.meta` (**now including `sum=`, computed by `sxpkg sum`, exactly as the Sayanox implementation writes it**) and `main.sa` into the local registry and `INDEX`; prints "commit registry/<name> to go online" | no (it never uploads) |

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
| Signed index or signed `pkg.meta` | Without a signature a compromised host could publish a matching `sum=` | needs a key and a trust policy, which is a product decision |
| A cryptographic hash | `pkgsum` is a 31-multiplier hash; collisions are easy to make on purpose | changing the sum changes every `sum=` in the repository and the test fixtures |
| Version ranges | `deps=` uses exact pins only, so resolution is trivial and reproducible | ranges need a solver; exact pins are the honest first step |
| `publish` upload | Publishing is a commit to this repository today; `publish` writes `pkg.meta`/`main.sa` into the local registry and `INDEX` and says so. `SAYANOX_ONLINE=1` deliberately changes nothing here | an upload API is a server design, not a client one, and an unreviewed upload path would defeat the registry's only trust mechanism (a commit others can read) |
| Exit codes from the Sayanox binary | The shell wrapper derives them from `FAILED`/`DEP` lines | the language has no exit builtin; adding one changes the compiler bootstrap |

## What must not be claimed

* That sxpkg is a secure package manager. It is a checksummed local lock file
  with an optional shell transfer.
* That online packages are verified by a signature.
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

Fetch records the checksum of the bytes it just received. There is no trusted
expected digest and no publisher identity; this detects later accidental edits,
**not a malicious first download**, substitution or deliberate collisions.
`source=` is not required or used as an integrity/provenance assertion.

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
