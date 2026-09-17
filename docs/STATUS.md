# Status

| Item | State |
|------|--------|
| Stage-2 full path | supported |
| Native runtime x86 (list/struct/control) | supported |
| **Bootstrap without Stage-2 (subset)** | **`make bootstrap-native`** |
| Full language without Stage-2/clang | not yet |
| LSP / sxpkg | supported |

```sh
make native
make bootstrap-native
```

See [BOOTSTRAP_NO_C_HOST.md](BOOTSTRAP_NO_C_HOST.md).
