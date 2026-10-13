# sxpkg online: a thin design

Status: **implemented, and the network is opt-in (2026-10-13).** The online
commands are shell code in `tools/sxpkg.sh`. This document fixes their contract,
names what is missing, and says what must not be claimed. It does not add a
network dependency to the bootstrap: two targets now cover this path without a
socket — `make test-sxpkg-online-local` (a `file://` registry: good accepted,
tampered rejected and removed, missing leaves no partial file) and `make
test-sxpkg-online-optin` (the refusal itself). Both are part of the
`true-selfhost-min` and `native-test` aggregates and both skip cleanly if
neither `curl` nor `wget` exists. Neither contacts a reachable host: every
remote URL in them is a `.invalid` name (RFC 2606), which fails in the
resolver.

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
| `sync` | shell | downloads `INDEX` and each locked `pkg.meta`/`main.sa` from `$SAYANOX_REGISTRY` | **yes** — opt-in (curl/wget) |
| `install` | shell | like `install-local`, but fetches a package that is missing from `.sayanox/registry/` | **yes** |
| `fetch <url> [name]` | shell | downloads one `main.sa` and locks it as `0.0.0` | **yes** |
| `publish` | shell | writes `pkg.meta` and `main.sa` into the local registry and `INDEX`; prints "commit registry/<name> to go online" | no (it never uploads) |

`SAYANOX_REGISTRY` overrides the default online index, which is the raw
`registry/` directory of the GitHub repository.

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
* No credentials are read or stored. No authentication is part of the design.

### Verification

`verify` checks every locked package against the local registry copy: the
version must match `sx.lock`, and `pkgsum(main.sa)` must equal `sum=` in
`pkg.meta`. Dependency-only packages are checked the same way. A mismatch is
reported as `MISMATCH` and the wrapper exits 1 (see `test-sxpkg-polish`).
The online path is tested against a local `file://` registry by
`make test-sxpkg-online-local` (not a bootstrap gate; skips without curl).

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
