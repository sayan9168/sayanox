# Sayanox bootstrap

**Canonical entry (no bash scripts):**

```bash
make true-selfhost
```

This uses the **11KB** `sxc_seed_min.c` to compile `compiler_min.sa` → gen1_min → gen2.

### Optional paths

| Command | Role |
|---------|------|
| `make true-selfhost-full` | 44KB `sxc_seed.c` path (legacy full seed) |
| `make seed-min-gen1` | Only build gen1 via min seed |
| `make gen3` | gen2 recompiles compiler_min; gen3→gen4 check |
| `make native-test` | Real x86-64 ELF, no second C compile for the program |

### Why a C seed still exists

A machine needs one executable compiler before it can run the Sayanox compiler. After gen1 exists, day-to-day work does not need the full 44KB seed.

Python and bash entry scripts are **not** part of the critical path.

See `docs/STATUS.md` for verified markers.
