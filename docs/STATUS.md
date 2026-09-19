# Status

## Unified Stage-3 self-host ✅
```sh
make selfhost
# → 0 1 2 42 99
```

One Sayanox compiler (`sxc.sa`) handles:
- `make` / `give` / call
- `hold` / `show`
- `while` / `when` / `otherwise`

## Package / GC / types
`sxpkg fetch|types` · `gc`/`gc_step` · runtime tags

## Bootstrap
Stage2 once → `sxc` binary → apps without re-running stage2
