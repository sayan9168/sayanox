# Status

## Native AOT
- Strings + concat + **gc()** + auto-gc
- **16 var slots**, **make / give / recursion**
- **else**, **// and /* */ comments**
- **arg(i)** / **arg_count()**, **and** / **or** / **not**
- **s[i]** string index (char code) · list index
- **assert** · better errors (line + caret)
- lists, fields, modules, files, run

```sa
hold s = "Hi"
show s[0]          // 72
assert s[0] == 72
when not (x < 0) { show 1 }
```

## Concurrent GC
- Stage-2: pthread · Native: STW + auto-gc

## Package / LSP
- `./tools/sxpkg.sh` · `./tools/sayanox-lsp.sh`
