# Memory: ownership + GC (full MVP)

## Implemented

| Feature | Detail |
|---------|--------|
| **String RC** | Heap strings have `SxStr` header (`magic`, `rc`). Literals are not released. |
| **List RC** | `SxList.rc` + `sx_list_retain` / `sx_list_drop` |
| **Auto-drop** | Reassign list → drop old; reassign string → `sx_str_release` |
| **Alias retain** | `hold ys = xs` (list) → retain; string name copy → retain |
| **GC registry** | `sx_gc_track` / `sx_gc_sweep` for heap string table |

## Examples

```bash
./selfhost/restore_stage2.sh
./selfhost/sx examples/gc_list_drop.sa --run
./selfhost/sx examples/gc_alias.sa --run
./selfhost/sx examples/gc_str_rc.sa --run
./selfhost/sx examples/gc_sweep.sa --run
```

## Limits

- Not a concurrent moving GC
- List alias shares buffer via RC (mutations visible through all aliases)
- String literals ("hi") are immortal; only heap strings are RC-managed
