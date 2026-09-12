# Stage-2 v0.3.24

## Always generic

`compiler.sa` is lowered by the **same** generic path as any `.sa` file (no semantic shortcut).

```bash
./selfhost/bootstrap_generic_compiler.sh
./selfhost/bootstrap_stage3.sh
```

## Struct syntax

```sa
struct Point {
    x,
    y
}
hold p = Point { 3, 4 }
show p.x
```

## hold reassignment

`hold pos = pos + 1` emits assignment if `pos` already declared.
