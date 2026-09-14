# Compiler in Sayanox (.sa)

## Status: subset complete

| Feature | In codegen.sa |
|---------|----------------|
| hold / assign number | yes |
| show number / name / call | yes |
| when / while | yes |
| make fn() / give number | yes |

```bash
./selfhost/step5_all.sh
```

Installs full `codegen.sa` then runs all demos (expect 42 each).

## Still out of subset

Multi-var names, params, otherwise, structs, strings/lists in .sa codegen.
Stage-2 C remains bootstrap for running `.sa` tools / general programs via `sx`.
