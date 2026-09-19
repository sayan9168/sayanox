# Status

## Native AOT
- **for i = a to b** · **break / continue**
- **substr(s, start, len)** · **string == / !=**
- **min / max / exit / chr / gc_info**
- **! and not** · assert · s[i]
- make/give/recursion · arg · and/or · gc

```sa
for i = 1 to 5 { show i }
hold t = substr("hello", 1, 3)  // ell
when s == "hello" { show 1 }
show min(3, 7) · max(3, 7)
exit(0)
```

## Concurrent GC
- Stage-2: pthread · Native: STW + gc_info + auto-gc

## Package / LSP
- `./tools/sxpkg.sh` · `./tools/sayanox-lsp.sh` v0.3
