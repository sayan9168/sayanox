# Build entrypoints (minimal shell)

Supported automation is **Makefile + Sayanox (`.sa`)**, not a pile of `.sh` scripts.

```sh
make stage2
make bootstrap-production   # runs bootstrap_production.sa
make native
make bootstrap-native       # no Stage-2 after native_aot build
make tools                  # sxfmt.sa, sx.sa
```

Sayanox drivers:

- `selfhost/sx.sa` — CLI
- `selfhost/bootstrap_production.sa`
- `tools/sxfmt.sa`

Legacy bootstrap `*.sh` removed where replaced.

Still required outside Sayanox: `make`, `clang` (and once for Stage-2 / native_aot C sources).
