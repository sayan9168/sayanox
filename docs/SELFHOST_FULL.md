# Full self-host progress (#1)

## Closed loop (done)

| Action | stage2? |
|--------|---------|
| Build sxc from frozen C | **No** — `make selfhost-fast` |
| Compile apps | **No** — `./selfhost/sxc` |
| Stable recompile of tests | **No** — `make selfhost-recompile` |
| Regenerate C after editing `sxc.sa` | **Yes** — `make selfhost` |

## Runtime in every emit

`sx_arg_count`, `sx_arg`, `sx_read_file`, `sx_write_file`, `sx_concat2`, `sx_len`, `sx_index`, lists, Point/Box/Vec3.

## Remaining for pure sxc→sxc.sa

Frontend still missing: `read_file` / `source[i]` / multi-arg `concat` as hold RHS, `write_file` statement emit.
