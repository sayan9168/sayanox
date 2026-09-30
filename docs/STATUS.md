# Status

Last updated: 2026-10-01 (CI path verified: true-selfhost, native-test, gen3, grammar, gc-test).

## Entry point

```bash
make true-selfhost
```

## CI (`.github/workflows/ci.yml`)

On every push/PR to `main`:

- `make true-selfhost`
- `make all`
- `make grammar`
- `make test`
- `make native-test`
- `make gc-test`
- `make gen3`

## Verified locally (clean clone)

| Command | Result |
|---------|--------|
| `make true-selfhost` | TRUE-SELFHOST-MIN-OK |
| `make native-test` | NATIVE-TEST-OK |
| `make gen3` | GEN3-OK |
| `make grammar` | GRAMMAR-OK |
| `make gc-test` | GC-RC-OK |

## Scope

Pure-min bootstrap only — not full-language self-host.
