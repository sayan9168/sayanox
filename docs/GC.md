# Memory: ownership + GC

## Implemented (Stage-2 C backend)

| Mechanism | What |
|-----------|------|
| **Arena (region)** | Strings from `concat` / `str` / `upper` / … → `sx_alloc`, freed at process exit |
| **List RC** | `SxList.rc`; `sx_list_retain` / `sx_list_drop` |
| **Auto-drop** | `hold xs = …` when `xs` already a list → `sx_list_drop(&xs)` before assign |

## Ownership rules

```sayanox
hold xs = [1, 2, 3]   // rc = 1, owns buffer
hold xs = [9, 8]      // drop old buffer, own new
hold s = concat("a","b")  // arena string
```

## Not yet

- Full mark-sweep concurrent GC
- String per-object refcount (arena covers temps)
- Shared list aliasing (`hold ys = xs`) without deep copy

## Test

```bash
./selfhost/restore_stage2.sh
./selfhost/sx examples/gc_arena_demo.sa --run
./selfhost/sx examples/gc_list_drop.sa --run
```
