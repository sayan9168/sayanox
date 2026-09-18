# Status

## Native AOT
- Strings: hold/show/concat/runtime `+` / len / ord
- **gc()** — stop-the-world mark-copy (to-space at 128KiB)
- lists, fields, make/call, modules, files, run

## Concurrent GC
- Stage-2 / `sx` path: pthread mark-sweep (docs/GC.md)
- Native path: STW `gc()` (safe mark-copy); concurrent collector remains Stage-2

## Stage-2 IR ↔ native
- See docs/NATIVE_IR.md — native covers most Stage-2 user language

## Package manager
```sh
./tools/sxpkg.sh init
./tools/sxpkg.sh add mylib
./tools/sxpkg.sh install
./tools/sxpkg.sh list
```

## LSP
```sh
./tools/sayanox-lsp.sh   # stdio JSON-RPC
```
See docs/LSP.md
