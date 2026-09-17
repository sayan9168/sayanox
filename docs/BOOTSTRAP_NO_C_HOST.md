# Toward bootstrap without Stage-2 C host

## Goal

Run Sayanox **without** `selfhost/stage2` for programs that fit the native subset.

## Today

```sh
make native
make bootstrap-native
# or: ./selfhost/bootstrap_native_only.sh
```

| Step | Needs Stage-2? | Needs clang again? |
|------|----------------|--------------------|
| `make native` | No | Once (build `native_aot`) |
| `./selfhost/native_aot in.sa out` | **No** | **No** |
| `./out` | No | No |

## Still needs Stage-2

Full grammar, modules, GC, all builtins, full self-host of `compiler.sa`.

## Roadmap

1. **Done:** native AOT subset without Stage-2 after one `make native`.
2. **Next:** more features in `native_aot` + a minimal compiler written in the subset.
3. **Later:** that compiler replaces Stage-2 for more of the language.
4. **Final:** implement `native_aot` in Sayanox (optional).
