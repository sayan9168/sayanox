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
./tools/sxpkg.sh install            # online: downloads from $ONLINE
./tools/sxpkg.sh install-local registry  # offline: local directory only
./tools/sxpkg.sh deps
./tools/sxpkg.sh list
./tools/sxpkg.sh info math
./tools/sxpkg.sh fetch https://example.com/x.sa mypkg
```

A Sayanox implementation of the local lock-file core is also available:

```sh
make sxpkg
./tools/sxpkg init
./tools/sxpkg add math 0.1.0      # also locks math's `deps=` closure
./tools/sxpkg list
./tools/sxpkg deps                # the resolved closure
./tools/sxpkg search math
./tools/sxpkg info math
./tools/sxpkg install [registry]  # offline: copies the closure in, sum-checked
./tools/sxpkg remove math
make test-sxpkg
```

`install` needs the destination folders to exist (Sayanox has no `mkdir`), so
the wrapper creates them first:

```sh
sh tools/sxpkg.sh install-local registry   # mkdir + the offline install above
sh tools/sxpkg.sh deps
```

The Sayanox binary supports local project/registry commands (`init`, `add`,
`deps`, `install`, `verify`, `sum`, `list`, `remove`, `seed`, `search`,
`info`). It never downloads, installs from, or publishes to the network.

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

Because Sayanox cannot create directories, a missing
`.sayanox/registry/<name>/` is reported rather than ignored:

```
sxpkg: MISSING calc: cannot write .sayanox/registry/calc/; run sh tools/sxpkg.sh install-local to create the folders
```

`sh tools/sxpkg.sh install-local [registry]` creates those folders and then
runs the install, so the usual flow is:

```sh
sh tools/sxpkg.sh init                     # sx.lock / sx.toml / .sayanox/registry
./tools/sxpkg add calc 0.1.0               # locks calc + its dep math
sh tools/sxpkg.sh install-local registry   # copies both in, sum-checked
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

**Not provided:** signatures, version ranges, a real solver, or any fetch
during resolve/install/verify — everything above reads local directories
only. `sync`, `install` (the shell one), `publish` and `fetch` in
`tools/sxpkg.sh` are still the only online commands, and no bootstrap target
uses them.

## Exit codes and the online design (2026-10-10)

* `tools/sxpkg.sh verify` and `install-local` exit **1** when the Sayanox
  binary reports a `FAILED` or `DEP` problem. The binary itself cannot set an
  exit status, so the wrapper reads its report. An unknown command exits **2**.
  Both are pinned by `make test-sxpkg-polish`.
* `add` warns when the package has no local registry copy yet.
* The online commands (`sync`, `install`, `fetch`, `publish`) and their
  thin-design limits are in [`SXPKG_ONLINE.md`](SXPKG_ONLINE.md). That document
  says what is not verified: atomic downloads, signatures and a cryptographic
  hash are all missing.
