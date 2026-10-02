# Status

Last updated: 2026-10-02

## Entry

```bash
make true-selfhost
```

## Phase-3 structs (seed-min)

```sa
struct Point {
  x,
  y
}
hold p = Point { 3, 4 }
show p.x
show p.y
```

Also supports named fields: `Point { x: 10, y: 20 }`.

Emits C `typedef struct { double x; double y; } Point;`.

`make test-struct` → TEST-STRUCT-OK.

Structs in **compiler_min / gen2** not yet (seed path only).

## Phase-2 lists

seed-min: full. gen2: literal + index.

## Phase-1 functions

seed-min + gen2: `make` / `give`.

## Clean-clone

| Target | Result |
|--------|--------|
| true-selfhost | TRUE-SELFHOST-MIN-OK |
| gen3 | byte-identical |
| test-fn / test-list / test-struct | OK |

## Scope

Pure-min + functions + lists + structs (seed). Next: structs in compiler_min.
