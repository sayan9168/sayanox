# Full self-host (Stage-3 closed loop)

| Step | Needs stage2? |
|------|---------------|
| Build `sxc` from frozen C | **No** — `make selfhost-fast` |
| Compile any `.sa` app | **No** — `./selfhost/sxc` |
| Regen C after editing `sxc.sa` | **Yes** — `make selfhost` |

```sh
make selfhost-fast
make selfhost-loop   # SELFHOST-LOOP-OK
```

Frontier: expand sxc so it can parse full `sxc.sa` (read_file, indexing, concat) without stage2.
