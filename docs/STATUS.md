# Status

| Item | State |
|------|--------|
| Multi-var codegen.sa | done (8 slots) |
| Struct/list codegen demos | done (`codegen_struct_list_test.sh`) |
| Production bootstrap | supported |
| Stage-2 build | fixed PLACEHOLDER via `build_stage2.c` |
| Full self-host / language bootstrap | supported scripts |
| LSP diagnostics | brace / hold / typo scan |
| Package registry | local + `search` / `REGISTRY_URL` |
| Zero C host | **not possible yet** |
| Legacy stage/step scripts | removed |

```sh
make stage2
bash selfhost/bootstrap_production.sh
bash selfhost/codegen_struct_list_test.sh
./selfhost/sx examples/hello.sa --run
```
