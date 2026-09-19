# Status

## Done
```sh
make selfhost          # once (uses stage2)
make app FILE=x.sa OUT=x.c BIN=x   # stage2-free after that
```

| Feature | |
|---------|--|
| make/give/call | ✅ |
| hold/show num+var | ✅ |
| show "string" | ✅ |
| while / when / elif / otherwise | ✅ |
| CLI paths | ✅ |
| Stage2-free app path | ✅ |

## Remaining
1. Full static types
2. OS-thread concurrent GC
3. sxc compiling full sxc.sa (still needs stage2 to *build* sxc)
4. Lists/structs in sxc path
5. One unified native+selfhost backend
6. Online package registry / full LSP
