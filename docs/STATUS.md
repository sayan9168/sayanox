# Status

## Native AOT
- Strings + runtime concat + **gc()** + auto-gc (bump > 100000)
- **16 variable slots** (FNV hash)
- **make / give / recursive functions** (var save/restore across calls)
- **else** synonym for **otherwise**
- lists, fields, modules, files, run

## Concurrent GC
- Stage-2: pthread mark-sweep
- Native: STW + pressure auto-gc

## Package / LSP
- `./tools/sxpkg.sh` · `./tools/sayanox-lsp.sh`
