# GC

## Native
- Stop-the-world mark-copy of tagged strings
- `gc` — force collection
- `gc_info()` — current bump (bytes used)
- Auto-gc when heap pressure high

## Stage-2
- pthread concurrent mark-sweep path

## Future
- True concurrent native GC (incremental)
