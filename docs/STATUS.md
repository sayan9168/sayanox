# Status

## Native AOT (latest local)
- Strings + runtime concat + **gc()** + auto-gc
- **16 variable slots** (FNV hash)
- **make / give / recursive functions** (save/restore vars across calls)
- **else** synonym for **otherwise**
- lists, fields, modules, files, run

```sa
make fib(n) {
  when n <= 1 { give n }
  else { give fib(n - 1) + fib(n - 2) }
}
hold result = fib(10)
show result   // 55
```

## Concurrent GC
- Stage-2: pthread mark-sweep
- Native: STW + pressure auto-gc

## Package / LSP
- `./tools/sxpkg.sh` · `./tools/sayanox-lsp.sh`
