# Status

Last updated: 2026-10-02

## Entry

```bash
make true-selfhost
```

## Source restore (no Python)

`selfhost/compiler_min.sa` is restored **offline** from `selfhost/compiler_min_gz/*.b64`
using only `base64` + `gzip` (shell). No Python, no curl.

## CI

- `make true-selfhost`
- `make native-test`
- `make gen3` (byte-identical gen3 == gen4)
- `make test-fn` (make/give via seed-min and gen2)

## Clean-clone verified

| Target | Result |
|--------|--------|
| `make true-selfhost` | TRUE-SELFHOST-MIN-OK |
| `make gen3` | GEN3-OK + byte-identical |
| `make test-fn` | TEST-FN-OK |

## Phase-1b functions (self-host)

Both **seed-min** and **compiler_min / gen2** support:

```sa
make add(a, b) {
  give a + b
}
hold r = add(40, 2)
show r
```

Numeric params only in Phase-1. Fixed-point still holds with make/give in the compiler.

## Scope

Pure-min + functions. Next: lists (Phase-2), structs (Phase-3).
