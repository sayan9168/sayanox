# Memory model (no prior limits)

## Features

| Feature | Behavior |
|---------|----------|
| **String RC** | All `hold` strings (including literals) become heap RC via `sx_str_dup` / `sx_str_new` |
| **List deep copy** | `hold ys = xs` → `sx_list_clone` (independent buffer) |
| **Auto release** | Reassignment drops/releases previous value |
| **Mark-sweep** | `sx_gc()` / `sx_gc_sweep()` cleans tracked dead heap strings |

## Examples

```bash
./selfhost/restore_stage2.sh
./selfhost/sx examples/gc_deep_list.sa --run
./selfhost/sx examples/gc_literal_rc.sa --run
./selfhost/sx examples/gc_str_rc.sa --run
./selfhost/sx examples/gc_list_drop.sa --run
```

## Note on concurrency

Stop-the-world mark-sweep + RC runs in the program thread. True concurrent/moving GC needs a different runtime (not required for correctness here).
