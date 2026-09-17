# Core path without Bash scripts

## Sayanox replaces Bash CLI logic

| Old (Bash) | New |
|------------|-----|
| `selfhost/sx` shell | **`selfhost/sx.sa`** → `sx_bin` |
| bootstrap helpers | **Sayanox** + small **C** builders |
| format/pkg | **`tools/sxfmt.sa`**, **`tools/sxpkg.sa`** |

## Build

```sh
make stage2
make sx
./selfhost/sx_bin examples/hello.sa /tmp/hello 1
```

## Builtins used by Sayanox tools

- `run("command")` — run a process
- `arg_count()` / `arg(i)` — CLI args

Stage-2 host remains **C** (necessary to emit machine code via clang). Tool **logic** is Sayanox, not Bash.
