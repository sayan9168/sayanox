# Status

Last updated: 2026-10-01

## Entry

```bash
make true-selfhost
```

## Source restore

`selfhost/compiler_min.sa` is restored **offline** from `selfhost/compiler_min_gz/*.b64`
(gzip+base64 of full production compiler with crepl).
Fallback: curl known-good base + `patch_crepl.py`.

## CI (`.github/workflows/ci.yml`)

- `make true-selfhost`
- `make native-test`
- `make gen3`
- `make grammar` / `make gc-test`

## Clean-clone verified

| Target | Result |
|--------|--------|
| `make true-selfhost` | TRUE-SELFHOST-MIN-OK |
| `make native-test` | NATIVE-TEST-OK |
| `make gen3` | GEN3-OK |

## Scope

Pure-min bootstrap only (not full-language self-host).
