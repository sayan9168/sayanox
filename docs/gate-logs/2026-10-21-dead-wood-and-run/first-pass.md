# First pass of the 2026-10-21 gate — two red rows

Kept because the failures were caused by this change, not inherited. The raw
per-gate logs from this pass were overwritten by the second pass; what is below
is what the logs and the `make` output said at the time.

| gate | result |
|---|---|
| `make doctor` | ok |
| `make test-doc-claims` | ok |
| `make gen3` | ok — `=== GEN3-OK ===`, `gen3 == gen4` byte-identical |
| `make test-language-deps` | **failed (2)** at `make test-seed-gc` — `seed_min: open at 0` |
| `make native-test` | **failed (2)** — `selfhost/seed_tests/sxlink.c:525: too few arguments to function 'sx_run'` |
| `make all-sayanox` | exit 1, by design |

## Why `test-seed-gc` broke

The recipe is a loop, not a list of names:

```make
for f in churn grow retain ops tmp; do ./$(SEED_MIN_BIN) selfhost/seed_gc_$$f.sa ...
```

`selfhost/seed_gc_{churn,grow,retain,tmp}.sa` were deleted by the dead-wood
pass because no file *named* them. Fixed by restoring all four; they are live
again and the gate is green in the second pass. This is the case for running
the gates after deleting, and for not trusting a name search the `Makefile`
can route around.

## Why `native-test` broke

A builtin named `run` shadows a user function of the same name.
`tools/sxlink.sa`, `tools/sxencode.sa` and `selfhost/native_primitives.sa` all
define their own `make run() -> num` helper, so gen2 rewrote their calls to the
zero-argument builtin `sx_run()`. Fixed by renaming the builtin to
`run_command` throughout and rebuilding the chain from the seed. See section 2
of `README.md`.
