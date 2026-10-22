# Toolchain (no Bash core)

> **The entry points named in this file do not exist.** There is no `make stage2`
> target, and no `selfhost/bootstrap_production.sh`,
> `bootstrap_full_selfhost.sh` or `bootstrap_full_language_selfhost.sh`. The
> placeholder scaffolding those documents leaned on — `selfhost/stage2_template.c`,
> `selfhost/stage2_src/`, `selfhost/sxc_full.c`, `selfhost/sxc_full_minimal.c`,
> `selfhost/restore_stage2.sh`, `selfhost/restore_stage2_template.sh`,
> `selfhost/restore_sxc.sh`, `selfhost/restore_sxc_full.sh` and the `selfhost/sx`
> CLI wrapper — was **deleted on 2026-10-21**, so it cannot pretend to be one.
> The supported path is
> `make doctor && make true-selfhost && make gen3 && make native-test`;
> `docs/FULL_LANGUAGE_SELFHOST.md` says what actually runs and
> `make test-doc-claims` keeps this banner honest.

```
make gen2     # Sayanox: selfhost/compiler_min.sa → gen2
./selfhost/gen2 file.sa out.c && cc -O2 -o out out.c
make native   # C bootstrap: selfhost/native_aot.c → native_aot
```

There is no `make stage2`: the Stage-2 host does not exist in this tree and
`sh selfhost/restore_stage2.sh` exits 1.

Builtins in Stage-2 for tooling: `run`, `arg`, `arg_count`.
