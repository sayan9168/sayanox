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

Override mirror:

```sh
export SAYANOX_REGISTRY=https://raw.githubusercontent.com/sayan9168/sayanox/main/registry
```
