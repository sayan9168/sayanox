# Status

## Native AOT
- Strings + concat + **gc()** + auto-gc
- **16 var slots**, **make / give / recursion**
- **else**, **// and /* */ comments**
- **arg(i)** / **arg_count()**, **and** / **or**
- lists, fields, modules, files, run

```sa
// comments work
when a and b { show 1 }
show arg(1)
make fib(n) {
  when n <= 1 { give n }
  else { give fib(n - 1) + fib(n - 2) }
}
```

## Concurrent GC
- Stage-2: pthread · Native: STW + auto-gc

## Package / LSP
- `./tools/sxpkg.sh` · `./tools/sayanox-lsp.sh`
