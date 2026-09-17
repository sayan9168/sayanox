# Status

| Item | State |
|------|--------|
| Multi-var / struct / list codegen | demos + tests |
| Production / self-host scripts | supported |
| Stage-2 PLACEHOLDER fix | `build_stage2.c` |
| **Native AOT MVP** | **Linux x86_64 `show <int>` — no clang for output** |
| LSP / sxpkg | supported |
| Full native (all features) | **not yet** |
| Zero C for bootstrap | not yet |

```sh
make stage2
make native
./selfhost/native_aot examples/hello.sa /tmp/hello_native && /tmp/hello_native
```

See [docs/NATIVE.md](NATIVE.md).
