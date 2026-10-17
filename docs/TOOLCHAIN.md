# Toolchain (no Bash core)

> **The entry points named in this file do not exist (verified 2026-10-13).**
> There is no `make stage2` target, and no `selfhost/bootstrap_production.sh`,
> `bootstrap_full_selfhost.sh` or `bootstrap_full_language_selfhost.sh`.
> `selfhost/stage2_template.c` is a 93-byte placeholder, `selfhost/stage2_src/`
> holds a README and an 11-byte placeholder, `selfhost/sxc_full.c` is a 30-line
> toy, and `bash selfhost/restore_stage2.sh` exits 1 with
> `error: missing Stage-2 seed`. The supported path is
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
