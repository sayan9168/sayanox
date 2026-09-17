# Bootstrap roadmap

## Today

1. `make stage2` → C Stage-2 binary (fetched/patched template)
2. Stage-2 lowers `.sa` → `.c` → `clang`
3. Sayanox `codegen.sa` handles multi-var / struct / list demos

## Next

1. Port more Stage-2 lowering into Sayanox modules
2. Keep one tiny C bootstrap only for the first `stage2` binary
3. Native/ISA backend (long term) — required to drop clang entirely

## Not claimed

Full production without C/clang is **not** done. That needs a real code generator for a machine ISA.
