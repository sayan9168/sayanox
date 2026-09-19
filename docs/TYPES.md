# Type system

## Runtime tags (native)
- `is_str(v)` / `is_num(v)`

## Stage-2
- Decl kinds: number vs string vs list
- `sxpkg types file.sa` heuristic report

## Annotations
```sa
// type: num
hold n = 1
when is_num(n) == 1 { show n }
```
