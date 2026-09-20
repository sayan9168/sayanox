# Structs on the sxc path

## Init
```sa
hold p = Point { 10, 20 }
show p.x
show p.y

hold q = Box { 3, 4 }
show q.a
show q.b

hold v = Vec3 { 1, 2, 3 }
show v.x
show v.y
show v.z
```

## Built-in typedefs
- `Point` — x, y
- `Box` — a, b
- `Vec3` — x, y, z

```sh
./selfhost/sxc examples/sxc_struct.sa /tmp/st.c
clang -O2 -o /tmp/st /tmp/st.c && /tmp/st
```
