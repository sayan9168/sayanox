# Online package registry

Public index:

```
https://raw.githubusercontent.com/sayan9168/sayanox/main/registry/INDEX
```

Packages under `registry/<name>/` (`pkg.meta`, `main.sa`).

## Commands

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

Override mirror:

```sh
export SAYANOX_REGISTRY=https://raw.githubusercontent.com/sayan9168/sayanox/main/registry
```
