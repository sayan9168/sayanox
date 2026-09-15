# Memory: ownership + region GC (MVP)

## Model

Sayanox v0.4 uses a **hybrid** model:

### 1. Numbers / bools — value types
Copied on assignment. No heap.

### 2. Strings (Stage-2 C backend) — **region (arena) GC**

- `concat`, `str`, `upper`, `lower`, `trim`, `read_file` allocate from a process-wide **arena** (`sx_alloc`).
- Arena is released once at **process exit** (`atexit`).
- No per-object free during the run → no use-after-free from string temps.

### 3. Lists — **unique ownership** (+ explicit drop)

- `SxList` owns its `data` buffer (`realloc` growth).
- `sx_list_drop(list)` frees the buffer (available in runtime).
- Reassignment does not auto-free the old list yet (MVP limit).

### 4. Rust `--run` VM — **owned values**

- `Value::String` / `List` / `Struct` are owned Rust values.
- Assignment **moves/clones** like a simple scripting language (no shared mutability).

## Ownership rules (language level)

| Kind | Rule |
|------|------|
| `hold x = 1` | value |
| `hold s = "hi"` | arena string (C) / owned (VM) |
| `hold xs = [1,2]` | owned list buffer |
| `hold y = x` | number copy; string/list share or clone by backend |

## Future

1. Ref-count headers on strings/lists
2. Auto `drop` on `hold` reassignment
3. Optional `--gc=rc` / `--gc=arena` flags

## Verify

```bash
./selfhost/restore_stage2.sh   # applies patch_stage2_rc.py
./selfhost/sx examples/greet.sa --run
./selfhost/sx examples/gc_arena_demo.sa --run
```
