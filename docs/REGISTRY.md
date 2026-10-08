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

The Sayanox binary supports local project/registry commands (`init`, `add`,
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
