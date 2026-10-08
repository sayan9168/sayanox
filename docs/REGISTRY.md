# Online package registry

Public index:

```
https://raw.githubusercontent.com/sayan9168/sayanox/main/registry/INDEX
```

Packages under `registry/<name>/` (`pkg.meta`, `main.sa`).

## Commands

The current shell implementation provides the full, local/online command set:

```sh
./tools/sxpkg.sh init
./tools/sxpkg.sh sync
./tools/sxpkg.sh search math
./tools/sxpkg.sh add math 0.1.0
./tools/sxpkg.sh install
./tools/sxpkg.sh list
./tools/sxpkg.sh info math
./tools/sxpkg.sh fetch https://example.com/x.sa mypkg
```

A Sayanox implementation of the local lock-file core is also available:

```sh
make sxpkg
./tools/sxpkg init
./tools/sxpkg add math 0.1.0
./tools/sxpkg list
./tools/sxpkg search math
./tools/sxpkg info math
./tools/sxpkg remove math
make test-sxpkg
```

The Sayanox binary supports local project/registry commands (`init`, `add`, `verify`, `sum`,
`list`, `remove`, `seed`, `search`, `info`). It does not yet download, install
or publish packages.

## Offline use path (no network)

`seed` writes a local registry under `.sayanox/registry/` (`hello` and `math`,
the math package defining `dbl`/`sqr`) into the project, and `use` reads it
back with a plain relative splice:

```sh
sh tools/sxpkg.sh init      # creates sx.lock / sx.toml / .sayanox/registry
sh tools/sxpkg.sh seed      # writes the sample packages (mkdir + write_file)
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
compares stdout. No bootstrap target touches the network — `sync`, `publish`
and `fetch` in `tools/sxpkg.sh` are the only online commands and are unused by
the bootstrap.

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

**`pkg.meta`.** Each package in `registry/<name>/pkg.meta` has four lines:

```
name=math
version=0.1.0
desc=tiny math helpers (dbl, sqr)
sum=718013937
```

**The sum.** `sum=` is a *content check*, not a security hash: starting from
`h = 0`, for each byte `b` of `main.sa` in order, `h = (h * 31 + b) mod
1000000007`. It is computed by the Sayanox tool itself (`sxpkg sum <file>`
prints `sxpkg: sum <N> <file>`; the tool is built by gen2). An independent
`od` + `awk` computation over the same bytes gives the same numbers for all
three sample packages. It catches an edited or truncated `main.sa` against its recorded
`pkg.meta`. It does not stop a deliberate forgery, and nothing here signs
anything. The current sums are hello `522968026`, math `718013937` and
strings `120085778`.

**`sxpkg verify`.** For every `name=version` in `sx.lock` it checks, offline:

* the project has a registry copy `.sayanox/registry/<name>/` (else
  `MISMATCH <name>: no registry copy`);
* the registry `pkg.meta` `version=` equals the locked version (else
  `MISMATCH <name>: locked at X but the registry has Y`);
* the `sum` of the copy's `main.sa` equals `pkg.meta`'s `sum=` (else
  `MISMATCH <name>: main.sa sums to A but pkg.meta says B`).

It prints `sxpkg: verify ok (N locked packages)` and exits 0 when all pass,
or `sxpkg: verify FAILED (N problem(s))` and exits non-zero otherwise. With no
`sx.lock` it says `sxpkg: no sx.lock; run init first`.

```sh
sh tools/sxpkg.sh verify
sh tools/sxpkg.sh sum registry/math/main.sa
make test-registry-sums   # every pkg.meta sum= matches its main.sa
```

The sums are regenerated when a package changes (`sxpkg sum` on the new
`main.sa`, then update `sum=`). `test-pkgs` edits the project's registry copy to show the mismatch,
then re-seeds the project to restore it.

**Not provided:** an online registry, signatures, dependency resolution, or
any fetch during verify. `sync`, `publish` and `fetch` in `tools/sxpkg.sh`
are still the only online commands, and no bootstrap target uses them.
