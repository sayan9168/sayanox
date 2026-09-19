# Status

## Native AOT
- **break / continue** in while
- **chr(n)** · **gc_info()** · **assert** · **not**
- **s[i]** string index · lists · make/give/recursion
- **arg(i)** · and/or · // comments · else
- gc() STW mark-copy + auto on pressure

```sa
hold i = 0
while i < 10 {
  hold i = i + 1
  when i == 3 { continue }
  when i == 7 { break }
  show i
}
show chr(65)   // A
show gc_info()
```

## Concurrent GC
- Stage-2: pthread mark-sweep
- Native: STW copy + gc_info() + auto-gc

## Package / LSP
- `./tools/sxpkg.sh` — init add list install search publish remove
- `./tools/sayanox-lsp.sh` — completion + diagnostics + hover (v0.3)
