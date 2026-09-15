# Memory model

## Features

| Feature | Behavior |
|---------|----------|
| **String RC** | Literals and copies become heap strings via `sx_str_dup` / `sx_str_new` |
| **List deep copy** | `hold ys = xs` → `sx_list_clone` (independent buffer; push to ys does not change xs) |
| **Auto release** | Reassignment drops list / releases string |
| **Mark-sweep** | `sx_gc()` cleans tracked dead heap strings |

```bash
./selfhost/restore_stage2.sh
./selfhost/sx examples/gc_deep_list.sa --run
./selfhost/sx examples/gc_literal_rc.sa --run
```

Stop-the-world RC + mark-sweep runs on the program thread (correctness without concurrent collector).
