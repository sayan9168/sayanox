# Memory: ownership + region GC (MVP)

## Model

### Numbers — values
Copied on assignment.

### Strings (Stage-2 C) — **arena / region GC**
- `concat`, `str`, `upper`, `lower`, `trim`, `read_file` → `sx_alloc` bump allocator
- Entire arena freed at **process exit** (`atexit`)
- No use-after-free on temporary strings

### Lists — **unique ownership**
- Buffer owned by `SxList`; `sx_list_drop` frees
- Auto-drop on reassignment: future work

### Rust `--run` VM — **owned values**
Rust `String` / `Vec` ownership; no manual free.

## Apply

```bash
./selfhost/restore_stage2.sh   # includes patch_stage2_rc.py
./selfhost/sx examples/gc_arena_demo.sa --run
./selfhost/sx examples/greet.sa --run
```

## Future
Ref-count headers, auto-drop on `hold` reassignment, `--gc=rc|arena`.
