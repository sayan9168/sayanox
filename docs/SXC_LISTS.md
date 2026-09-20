# Lists (and structs) on the sxc path

## Lists
```sa
hold xs = [10, 20, 30]
show xs[0]
show xs[1]
```

Emits `SaList` + `sa_list_get` in the generated C.

```sh
./selfhost/sxc examples/sxc_list.sa /tmp/l.c
clang -O2 -o /tmp/l /tmp/l.c && /tmp/l
# 10 20 30
```

## Structs
- Runtime includes `typedef struct { double x; double y; } Point;`
- `show p.x` / `show p.y` field access is recognized
- Full `struct Name { ... }` + `hold p = Point { 1, 2 }` init is Stage-2 complete; sxc init is next step
