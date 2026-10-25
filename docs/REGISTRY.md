# Online package registry

Public index:

```
https://raw.githubusercontent.com/sayan9168/sayanox/main/registry/INDEX
```

Packages under `registry/<name>/` (`pkg.meta`, `main.sa`).

## Commands

There is one program, `./tools/sxpkg`, built from `tools/sxpkg.sa` by gen2
(`make sxpkg`). It answers every command; `tools/sxpkg.sh` was deleted on
2026-10-22 and nothing replaces it.

```sh
make sxpkg
./tools/sxpkg init
./tools/sxpkg sync                    # http(s): needs an opt-in, see below
./tools/sxpkg search math
./tools/sxpkg add math 0.1.0          # also locks math's `deps=` closure
./tools/sxpkg install                 # copy the lock closure in, sum-checked
./tools/sxpkg install registry        # the same, from an explicit source dir
./tools/sxpkg install-local registry  # offline: local directory only
./tools/sxpkg deps                    # the resolved closure
./tools/sxpkg list
./tools/sxpkg info math
./tools/sxpkg fetch https://example.com/x.sa mypkg
./tools/sxpkg verify
./tools/sxpkg publish
./tools/sxpkg sha256 registry/math/main.sa   # the SHA-256 of one file
./tools/sxpkg sign math                      # keyed signature into pkg.meta
./tools/sxpkg authenticate [math]            # check the signature(s)
```

`SAYANOX_ROOT` moves the project (every path is built through it), so
`SAYANOX_ROOT=project tools/sxpkg init` needs no `cd`. The network is opt-in:
`SAYANOX_ONLINE=1 tools/sxpkg sync`, or `tools/sxpkg --online sync`. A
`file://` URL or a plain path is not the network and needs no permission.

The only program the tool starts is the transfer itself: `curl`, or `wget`
when there is no curl, found by scanning `PATH`. Everything else -- the
opt-in policy, the `.part` staging, the checksum acceptance, the rollback, the
exit statuses -- is Sayanox code in `tools/sxpkg.sa`. It reads no manifest
with `grep`/`cut`/`tr` and copies no tree with `cp`.

## Offline use path (no network)

`seed` writes a local registry under `.sayanox/registry/` (`hello` and `math`,
the math package defining `dbl`/`sqr`) into the project, and `use` reads it
back with a plain relative splice:

```sh
./tools/sxpkg init          # creates sx.lock / sx.toml / .sayanox/registry and seeds
./tools/sxpkg seed          # writes the sample packages
./tools/sxpkg add math 0.1.0
```

```sayanox
use ".sayanox/registry/math/main.sa"
show dbl(21)
show sqr(6)
```

`make test-pkgs` pins this path: it asserts the seeded `INDEX`, `list`,
`search` and `info` output, then compiles the `use` program above with
seed-min and gen2 (and native when `selfhost/native_aot` is built) and
compares stdout. No bootstrap target touches the network — `sync` and a remote `fetch` are the
only commands that can open a socket, both need an explicit opt-in, and the
bootstrap never runs them.

Override mirror:

```sh
export SAYANOX_REGISTRY=https://raw.githubusercontent.com/sayan9168/sayanox/main/registry
```

## Offline lock and integrity sums

Everything in this section works with no network. It is what
`make test-sxpkg`, `make test-pkgs` and `make test-registry-sums` check.

**Lock file.** `sx.lock` holds one `name=version` line per package the project
has added (`sxpkg add`). It records *which* version a project uses, nothing
more. Malformed lines are reported by `verify`, not silently skipped.

**`pkg.meta`.** Each package in `registry/<name>/pkg.meta` has four lines,
plus the two the tool records itself since 2026-10-22:

```
name=math
version=0.1.0
desc=tiny math helpers (dbl, sqr)
sum=718013937
sha256=20c269795b03f933a723721400d7f5eef29aa8df6dd43a058b437f0e5edfce4e
origin=seed:builtin
```

and, once the package has been signed, two more:

```
signer=c48a01f49fd0f2cc
sig=f208da529095dde17fb59dea682aff26d27d8e39a515756dd3630369cbc3d24b
```

**The sum.** `sum=` is a *content check*, not a security hash: starting from
`h = 0`, for each byte `b` of `main.sa` in order, `h = (h * 31 + b) mod
1000000007`. It is computed by the Sayanox tool itself (`sxpkg sum <file>`
prints `sxpkg: sum <N> <file>`; the tool is built by gen2). An independent
`od` + `awk` computation over the same bytes gives the same numbers for all
three sample packages. It catches an edited or truncated `main.sa` against its recorded
`pkg.meta`, but it does not stop a deliberate forgery: two files that differ by
`+1` in one byte and `-31` in the next have the *same* `sum=`.
`make test-sxpkg-crypto` builds exactly that collision -- `give` changed to
`hJve` in the seeded `math/main.sa` keeps `sum=718013937` -- and requires
`verify` to refuse it, which it can only do through `sha256=`. The current
sums are hello `522968026`, math `718013937` and strings `120085778`.

**The digest.** `sha256=` is the SHA-256 of `main.sa`, in lower-case hex,
computed by `stdlib/crypto.sa` (pure Sayanox, see
[STDLIB.md](STDLIB.md#stdlibcryptosa----sha-256-and-hmac-sha256)).
`sxpkg sha256 <file>` prints it for any file and agrees with `sha256sum`.
`seed`, `publish` and `fetch` record it; `verify` and `install` check it.
`sum=` is still written and still checked, so a registry written by an older
tool keeps verifying.

**The origin.** `origin=` records where the package entered the project:
`seed:builtin` for the sample packages, `publish:<path>` for a local publish,
`fetch:<url-or-path>` for a fetch. It is provenance, not proof -- whoever can
write `pkg.meta` can write `origin=` -- so it answers "where did this come
from" for a tree you control, not "who vouches for this".

**Signing.** `sxpkg sign <name>` adds `signer=` and `sig=` to a package's
`pkg.meta`:

```
sig    = HMAC-SHA256(secret, "sayanox-pkg-v1\nname=<n>\nversion=<v>\nsha256=<d>\n")
signer = the first 16 hex digits of SHA-256(secret)
```

The secret comes from `SAYANOX_SIGN_KEY`, else the file named by
`SAYANOX_SIGN_KEYFILE`, else `.sayanox/keys/default.key` (one trailing newline
is trimmed, so a key file written by `echo` works).

This is a **symmetric, keyed digest, not a public-key signature**: the
checker needs the same secret the signer used. It proves that whoever holds
that secret signed these exact bytes under this exact name and version; it
does not let a stranger verify a package from a publisher they have never
shared a key with. The tool says so in its own header comment, and nothing in
this repository claims otherwise.

`sxpkg authenticate [name]` checks one package or the whole lock closure and
prints one line per package:

| Line | Meaning | Exit |
|---|---|---|
| `sxpkg: authentic <name> signer=<id>` | `sig=` matches the key in hand | 0 |
| `sxpkg: UNSIGNED <name>` | no `sig=` recorded | 0 (1 under `SAYANOX_REQUIRE_SIGNED=1`) |
| `sxpkg: NOKEY <name>` | signed, but no key is available here | 0 (1 under `SAYANOX_REQUIRE_SIGNED=1`) |
| `sxpkg: BAD <reason>` | wrong key, edited `main.sa`, or a rewritten `sha256=` | 1 |

`SAYANOX_REQUIRE_SIGNED=1` turns "cannot check" into a failure, for a project
that wants every package authenticated or none installed. Over a registry
with no signatures at all, `verify`'s output is byte-identical to the
pre-signature tool's (`make test-sxpkg-crypto` pins that with `cmp`); a signed
one adds `sxpkg: signature ok <name>`.

**`sxpkg verify`.** For every `name=version` in `sx.lock` it checks, offline:

* the project has a registry copy `.sayanox/registry/<name>/` (else
  `MISMATCH <name>: no registry copy`);
* the registry `pkg.meta` `version=` equals the locked version (else
  `MISMATCH <name>: locked at X but the registry has Y`);
* the `sum` of the copy's `main.sa` equals `pkg.meta`'s `sum=` (else
  `MISMATCH <name>: main.sa sums to A but pkg.meta says B`);
* when `pkg.meta` records one, the SHA-256 of the copy's `main.sa` equals
  `sha256=` (else `MISMATCH <name>: main.sa hashes to A but pkg.meta says B`);
  a package written by an older tool has no `sha256=` and is checked on `sum=`
  alone, so nothing that verified before stops verifying;
* when `pkg.meta` records a signature and a key is available, the signature
  matches (`sxpkg: signature ok <name>`, else a `BAD` line and exit 1).

It prints `sxpkg: verify ok (N locked packages)` and exits 0 when all pass,
or `sxpkg: verify FAILED (N problem(s))` and exits non-zero otherwise. With no
`sx.lock` it says `sxpkg: no sx.lock; run init first`.

```sh
./tools/sxpkg verify
./tools/sxpkg sum registry/math/main.sa
make test-registry-sums   # every pkg.meta sum= matches its main.sa
```

The sums are regenerated when a package changes (`sxpkg sum` on the new
`main.sa`, then update `sum=`). `test-pkgs` edits the project's registry copy to show the mismatch,
then re-seeds the project to restore it.

## Dependencies and the offline install

`pkg.meta` has a fifth line, `deps=`, holding a comma-separated list of
`name@version` pins:

```
name=calc
version=0.1.0
desc=tiny helpers built on math (dblsqr)
deps=math@0.1.0
sum=807763569
```

A pin is **exact**: there are no ranges and no "compatible with" operator.
`calc@0.1.0` needs precisely `math@0.1.0`, and anything else is an error.

`registry/calc` is the sample that exercises this: its `main.sa` starts with
`use ".sayanox/registry/math/main.sa"` and defines `dblsqr`, which calls
`math`'s `dbl` and `sqr`.

**Resolution.** `sxpkg add calc 0.1.0` locks `calc` *and* walks its `deps=`
transitively, so the lock ends up holding both:

```sh
./tools/sxpkg add calc 0.1.0
#   sxpkg: locked math 0.1.0 (dependency of calc)
#   sxpkg: locked calc 0.1.0
#   sx.lock ->  calc=0.1.0
#               math=0.1.0
```

`sxpkg deps` prints the closure, and reports the two ways it can be
unsatisfied:

```
sxpkg: DEP calc needs math@0.1.0 which is not in sx.lock; run: sxpkg add math 0.1.0
sxpkg: DEP calc needs math@0.1.0 but sx.lock has 0.2.0
```

**Install.** `sxpkg install [registry]` copies every package in the closure
out of a local registry *directory* (default `./registry`, i.e. the one in
this repository) into `.sayanox/registry/<name>/`. For each package it
checks, before writing anything:

* the source `pkg.meta` says the version `sx.lock` pins;
* the source `main.sa` sums to the `sum=` in that `pkg.meta`;
* the destination copy (if any) already agrees — reported as `ok`, not
  re-copied.

The plain `install [registry]` form does not create destinations: it reports
what it could not write. `install-local` and the no-argument `install` do
create them (`ensure_dir` is `mkdir -p` over `make_dir`). The usual flow is:

```sh
./tools/sxpkg init                         # sx.lock / sx.toml / .sayanox/registry
./tools/sxpkg add calc 0.1.0               # locks calc + its dep math
./tools/sxpkg install-local registry       # copies both in, sum-checked
./tools/sxpkg verify                       #   sxpkg: verified calc 0.1.0
                                           #   sxpkg: verified math 0.1.0
                                           #   sxpkg: verify ok (2 locked packages)
```

`verify` walks the same closure, so a package pulled in only as a dependency
is checked too — it is verified even though it is not one of your
hand-written lock lines.

`use` sees a package's own `use` lines: `use ".sayanox/registry/calc/main.sa"`
brings in calc, and calc's `use ".sayanox/registry/math/main.sa"` is spliced
along with it (paths resolve from the main program's directory). seed-min,
gen2 and native all agree on the result.

`make test-pkgs` pins all of the above, including the two `sxpkg: DEP ...`
errors and the "cannot write" message.

**Not provided:** public-key signatures, version ranges, a real solver, or any
fetch during resolve/verify — everything above reads local directories only.
Signing is the symmetric kind described above: a shared secret, not a
publisher's private key. The
http(s) halves of `sync`, `install` and `fetch` are the only commands that can
open a socket, they need an explicit opt-in, and no bootstrap target uses
them.

## Exit codes and the online design (2026-10-10)

* `verify`, `install`, `install-local` and `search` exit **1** when they report
  a `FAILED`/`DEP` problem or have no index to read. An unknown command exits
  **2**. The program sets these itself; the shell that used to read its report
  is gone. All pinned by `make test-sxpkg-polish`.
* `add` warns when the package has no local registry copy yet.
* The online commands (`sync`, `install`, `fetch`, `publish`) and their
  thin-design limits are in [`SXPKG_ONLINE.md`](SXPKG_ONLINE.md). Since
  2026-10-22 `sha256=` and symmetric HMAC `sig=`/`signer=` are recorded and
  checked (`make test-sxpkg-crypto`), and since **2026-10-24** `stdlib/pubkey.sa`
  + `tools/sxpkg.sa` add **Curve25519 Schnorr-SHA256 public-key signatures** for
  both packages (`sxpkg keygen`, `sxpkg pubsign`, `sxpkg verify-pub`, `pubsig=`)
  and registry indices (`sxpkg sign-index`, `sxpkg verify-index`, `INDEX.sig`),
  pinned against `.sayanox/trusted_keys` and enforced on `sync` and `verify`
  under `SAYANOX_REQUIRE_PUBKEY=1` (`make test-sxpkg-pubkey`, verified with the
  publisher's `.sec` secret seed deleted from disk). Online key distribution /
  certificate authorities are still outside scope, and transfers stage via
  `.part` files.

### Offline search and process failures (2026-10-11)

`search` now only reads the local index. If it is absent, it exits nonzero
with `no local index; run seed (offline) or sync (explicit network)`; it never
silently switches to network access. Network transfers remain
explicit `sync`, `install` or `fetch` operations; bootstrap uses none of them.

A project root that is not a directory fails the same way it did when the
wrapper's `cd` failed: `sxpkg: could not run verify in project <path>`, exit 1.
`make test-pkg-errors` (part of `test-pkgs`) checks both that and the absent
index. `sum=` is still not cryptographic (`sha256=` is, and is checked
alongside it), and none of these checks are a sandbox for untrusted package
trees or symlinks: they say what the bytes are, not that running them is safe.
