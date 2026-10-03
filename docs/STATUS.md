# Status

Last updated: 2026-10-03

## Entry

```bash
make true-selfhost
```

## Language coverage (seed-min + gen2)

| Feature | seed-min | gen2 / compiler_min |
|---------|----------|---------------------|
| hold/show/when/while | yes | yes |
| make/give | yes | yes |
| lists `[...]` index | yes | yes |
| list `len` / `push` | yes | **yes** |
| structs def/literal/field | yes | **yes** |

## Examples

```sa
struct Point {
  x,
  y
}
hold p = Point { 3, 4 }
show p.x

hold xs = [10, 20, 30]
show len(xs)
hold xs = push(xs, 40)
```

## Tests

| Target | Result |
|--------|--------|
| true-selfhost | TRUE-SELFHOST-MIN-OK |
| gen3 | byte-identical |
| test-struct / test-list / test-fn | OK |
| test-gen2-struct | TEST-GEN2-STRUCT-OK |
| test-gen2-list | TEST-GEN2-LIST-OK |

## Scope

Pure-min self-host with functions, lists, and structs end-to-end on gen2.
Next optional: modules, string fields, nested structs.
