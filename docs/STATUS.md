# Status

Last updated: 2026-10-03

## Entry

```bash
make true-selfhost
```

## Coverage

| Feature | seed-min | gen2 |
|---------|----------|------|
| hold/show/when/while | yes | yes |
| make/give | yes | yes |
| lists + len + push | yes | yes |
| structs + field | yes | yes |
| `%` modulo | **yes** | not yet |
| `else` | **yes** | not yet |
| `use "file.sa"` | **yes** | not yet |

## Honest boundary

`%` / `else` / `use` ship on **seed-min** today. gen2 keeps structs/lists stable. Expanding `compiler_min` for `%`/`else` desynced gen2 self-compile (string escapes); rolled back that path so `make true-selfhost` stays green.

## Later

modules on gen2, string/nested fields, native lists/structs, Stage-2 parity.
