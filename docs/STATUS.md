# Status

| Item | State |
|------|--------|
| Stage-2 full path | supported |
| codegen.sa multi-var / struct / list demos | supported |
| **Native AOT step 2** | **hold / show / when / while — no clang for binary** |
| LSP / sxpkg | supported |
| Full native (all features + live codegen) | later |
| Zero C bootstrap | later |

```sh
make native
./selfhost/native_aot examples/hello.sa /tmp/n && /tmp/n
```
