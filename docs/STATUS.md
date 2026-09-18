# Status

## Native AOT
- Strings + runtime concat + **gc()** (STW mark-copy) + **auto-gc** when bump > 100000
- **16 variable slots** (FNV hash — fewer collisions)
- lists, fields, make/call, modules, files, run

## Concurrent GC
- Stage-2 path: pthread mark-sweep (docs/GC.md)
- Native: STW + pressure-triggered auto-gc

## Package / LSP
- `./tools/sxpkg.sh` · `./tools/sayanox-lsp.sh`
