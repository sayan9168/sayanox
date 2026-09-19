# Self-host

## Compilers written in Sayanox
| Binary | Source | Grammar |
|--------|--------|--------|
| sxc | sxc.sa / sxc.sa.b64 | hold show while when |
| sxc_fn | sxc_fn.sa | make give call hold show |

## Bootstrap once
```sh
make stage2
make selfhost
make selfhost-fn
```

## Then no stage2 for app compile
```sh
./selfhost/sxc
./selfhost/sxc_fn
clang -o app selfhost/sxc_emit.c && ./app
```
