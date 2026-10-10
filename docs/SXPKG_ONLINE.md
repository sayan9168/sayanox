# sxpkg online: a thin design

Status: **design only, 2026-10-10.** The online commands already exist as
shell code in `tools/sxpkg.sh`. This document fixes their contract, names what
is missing, and says what must not be claimed. It does not add a network
dependency to the bootstrap, and nothing in it is on any `make` gate.

## Principles

1. **The network is optional and lives outside the bootstrap.** Every target in
   `make doctor`, `true-selfhost`, `gen3` and `native-test` is offline. Online
   commands are shell-only (`curl`, falling back to `wget`) and are never run
   by a gate.
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
| `sync` | shell | downloads `INDEX` and each locked `pkg.meta`/`main.sa` from `$SAYANOX_REGISTRY` | **yes** (curl/wget) |
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

* A download that fails leaves no partial file behind. The current code writes
  straight to the destination, so **this rule is not yet met** (see Missing).
* A transfer is accepted only when the Sayanox binary's `verify` passes on the
  result. The sum check, not the transport, is the acceptance test.
* No credentials are read or stored. No authentication is part of the design.

### Verification

`verify` checks every locked package against the local registry copy: the
version must match `sx.lock`, and `pkgsum(main.sa)` must equal `sum=` in
`pkg.meta`. Dependency-only packages are checked the same way. A mismatch is
reported as `MISMATCH` and the wrapper exits 1 (see `test-sxpkg-polish`).

## Missing (and why it is not in this pass)

| Gap | Why it matters | Why not now |
|---|---|---|
| Atomic downloads (temp file, then rename) | A dropped connection can leave a truncated `main.sa`; `verify` would catch it, but only later | needs a `mv` in the shell path, which the offline gates do not otherwise use |
| Signed index or signed `pkg.meta` | Without a signature a compromised host could publish a matching `sum=` | needs a key and a trust policy, which is a product decision |
| A cryptographic hash | `pkgsum` is a 31-multiplier hash; collisions are easy to make on purpose | changing the sum changes every `sum=` in the repository and the test fixtures |
| Version ranges | `deps=` uses exact pins only, so resolution is trivial and reproducible | ranges need a solver; exact pins are the honest first step |
| `publish` upload | Publishing is a commit to this repository today | an upload API is a server design, not a client one |
| Exit codes from the Sayanox binary | The shell wrapper derives them from `FAILED`/`DEP` lines | the language has no exit builtin; adding one changes the compiler bootstrap |

## What must not be claimed

* That sxpkg is a secure package manager. It is a checksummed local lock file
  with an optional shell transfer.
* That online packages are verified by a signature.
* That the bootstrap needs, or tests, the network. It does not.
