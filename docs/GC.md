# Concurrent GC

## Design

| Piece | Implementation |
|-------|----------------|
| **Atomic RC** | `_Atomic int rc` on `SxStr` / `SxList` |
| **Background thread** | `sx_gc_bg` every ~50ms runs mark-sweep |
| **Deferred free** | String `rc` hits 0 → free on concurrent sweep |
| **Deep list copy** | `sx_list_clone` (no shared mutation) |
| **Literal → heap** | `sx_str_dup` on `hold` |
| **Shutdown** | `atexit` joins GC thread and final sweep |

Link flag: **`-pthread`** (wired into `selfhost/sx`).

```bash
./selfhost/restore_stage2.sh
./selfhost/sx examples/gc_concurrent.sa --run
./selfhost/sx examples/gc_deep_list.sa --run
./selfhost/sx examples/gc_literal_rc.sa --run
```

Mutator = your program thread; collector = dedicated GC thread (concurrent mark-sweep over the registry, not a moving collector).
