# Full self-host (Stage-3)

## Claim
Compiler logic is **Sayanox** (`selfhost/sxc.sa`).
C `stage2` is bootstrap only (one lower step).

## Loop
```
stage2   compiles  sxc.sa           → sxc
sxc      reads     sxc_test_in.sa   → sxc_emit.c  (all integers → printf)
clang    links                      → sxc_run
run                                 → 10 / 32
```

## Commands
```sh
make selfhost
```

## What sxc does
- Reads source text (`read_file`)
- Scans **all integer literals**
- Emits C that prints each value
- Supports up to 8 numbers per file

## Input example (`sxc_test_in.sa`)
```sa
hold a = 10
hold b = 32
show a
show b
```

## Limits
- Not full grammar yet (no full parse of hold/show AST)
- Still needs stage2 once + clang to link emitted C
- Grow toward parsing keywords next; then replace stage2
