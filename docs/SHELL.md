# Shell scripts (supported only)

## Keep

- `selfhost/restore_stage2.sh`
- `selfhost/bootstrap_production.sh`
- `selfhost/bootstrap_full_selfhost.sh`
- `selfhost/bootstrap_full_language_selfhost.sh`
- `selfhost/bootstrap_native_only.sh`
- `selfhost/codegen_struct_list_test.sh`
- `tools/sxfmt.sh`, `tools/sayanox-lsp.sh`, `tools/sxrepl.sh`, `tools/sxpkg`

## Prefer Make

```sh
make stage2
make native
make bootstrap-native
make sx
```

## Removed

- `bootstrap_cycle.sh`
- `run_sayanoxc.sh`
- `test_stage2.sh`
- `stage2_src/decode.sh`
- numbered `stage*.sh` / `step*.sh`
