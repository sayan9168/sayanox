# Status

Last updated: 2026-10-02

## Entry

```bash
make true-selfhost
```

## Phase-2b lists (seed-min + compiler_min/gen2)

```sa
hold xs = [10, 20, 30]
hold a = xs[0]
show a
```

Runtime: `sx_list` + `sx_llit` / `sx_lget` / `sx_llen` / `sx_lpush`.

| Path | Lists |
|------|-------|
| seed-min | literal, index, push, len |
| gen2 / compiler_min | literal + index |

Fixed-point still holds (gen3 == gen4).

## Phase-1b functions

seed-min + compiler_min / gen2: `make` / `give`.

## Clean-clone

| Target | Result |
|--------|--------|
| true-selfhost | TRUE-SELFHOST-MIN-OK |
| gen3 | byte-identical |
| gen2 lists | 10 / 20 / 30 |

## Scope

Pure-min + functions + lists. Next: push/len in gen2 path, structs (Phase-3).
