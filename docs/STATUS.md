# Status

Last updated: 2026-10-02

## Entry

```bash
make true-selfhost
```

## Phase-2 lists (seed-min)

```sa
hold xs = [10, 20, 30]
show xs[0]
hold xs = push(xs, 40)
show len(xs)
```

Runtime: `sx_list` + `sx_llit` / `sx_lget` / `sx_llen` / `sx_lpush`.

`make test-list` → TEST-LIST-OK.

Lists in **compiler_min / gen2** not yet (seed path only).

## Phase-1b functions

seed-min + compiler_min / gen2: `make` / `give`.

## Clean-clone

| Target | Result |
|--------|--------|
| true-selfhost | TRUE-SELFHOST-MIN-OK |
| gen3 | byte-identical |
| test-fn | TEST-FN-OK |
| test-list | TEST-LIST-OK |

## Scope

Pure-min + functions + lists (seed). Next: lists in compiler_min, then structs.
