# Status

## Unified Stage-3 + CLI ✅
```sh
make selfhost
./selfhost/sxc input.sa output.c
# → 0 1 2 42 99
```

### Grammar
- make / give / call
- hold / show
- while / when / otherwise

### CLI
```
sxc [input.sa] [output.c]
```
Defaults: `selfhost/sxc_test_in.sa` → `selfhost/sxc_emit.c`

Stage-2 runtime: `arg_count()` · `arg(i)`
