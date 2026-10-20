# Contributing to Sayanox

Thank you for contributing to Sayanox.

## Development principles

- Keep the language implementation understandable and deterministic.
- Prefer Sayanox-owned compiler stages over host-language shortcuts.
- Keep the bootstrap small and explicit.
- Do not add a new runtime dependency when an existing Sayanox facility is sufficient.
- Keep user-facing text and source code comments in English.
- Add a focused example or regression test for new language behavior.
- Never claim a self-hosting stage is complete until the bootstrap cycle has been reproduced from a clean checkout.

## Compiler architecture

The intended pipeline is:

```text
source -> lexer -> parser -> AST -> semantic analysis -> checked AST -> IR -> lowering -> backend
```

The C seed exists only to build gen1; preferred path is `make true-selfhost` (seed-min).

## Local workflow

```sh
make doctor
make true-selfhost
make gen3
make native-test
```

For changes to compiler stages, also inspect the generated output and run the repository CI checks.

## Continuous integration

`.github/workflows/ci.yml` runs the four gates above on every push to `main`
and every pull request, on a clean checkout, with `python`, `node`, `ruby`,
`perl`, `curl` and `wget` replaced by shims that log and fail — a gate that
reaches for an interpreter or the network fails instead of quietly passing.

They run as four jobs, because sequentially they do not fit in one:

| job | runs | needs |
|---|---|---|
| `bootstrap` | `make doctor`, `make true-selfhost` | — |
| `fixed-point` | `make gen3` | the `gate-binaries` hand-off |
| `native` | `make native-test` | the `gate-binaries` hand-off |
| `audit` | tracked-artifact check, `make all-sayanox` inventory | — |

The only thing crossing a job boundary is the `gate-binaries` artifact: three
binaries — `gen2`, `gen1_min`, `seed/sxc_seed_min` — and the two generated C
files they came from, `gen2.c` and `gen1_min.c`, all of them built by the
`bootstrap` job with `make` from tracked sources. The C files travel because
`selfhost/test_compiler_source_features.sh` greps all four generated sources,
and under `set -eu` one missing file is a silent exit 1 with nothing in the log
to explain it. Each consumer `touch`es the C files and *then* the binaries:
an artifact does not preserve mtimes, make rebuilds a target whose prerequisite
is the same age as it, and without the ordering the job that was just handed a
built `gen2` would spend four minutes building it again from the restored
`gen2.c` — and `make gen3` would stop being the gate it is. Both consumers then
*run* the compilers on `selfhost/mini_in.sa` before `make`, because the point of
a hand-off is a compiler that works, not files that exist.

Each job has its own `timeout-minutes: 45`. The first green run of this shape,
[`39477167629`](https://github.com/sayan9168/sayanox/actions/runs/39477167629),
took 26m17s wall with a longest job of 14m29s; a second,
[`39490134812`](https://github.com/sayan9168/sayanox/actions/runs/39490134812),
took 21m57s with a longest job of 12m20s. The whole run is therefore *not*
reliably faster than the single sequential job it replaced, which the runner
killed at 25m0s, because gates 3 and 4 still wait for `bootstrap` and the total
moves with the runner. What the split buys is that the ceiling applies per job,
so a gate that gets slow fails as that gate, with its own log, instead of the
run being cancelled at a round number.

Beside it, `.github/workflows/full-bootstrap.yml` re-runs the whole chain in one
job, in order, with no artifacts and no cache, nightly and on demand; if that
goes red while CI is green, the parallel shape hid something and `ci.yml` is
what needs fixing.

`make all-sayanox` is **supposed to fail**: it prints the measured inventory of
what is still not Sayanox and exits 1, and `make test-doc-claims` fails if it
ever starts returning 0 without `docs/ALL_SAYANOX_PHASE.md`, `docs/STATUS.md`
and `README.md` being updated in the same change. The `audit` job asserts that
it still refuses.

Before opening a pull request, run the four targets locally. A gate that only
passes in CI is not a gate.

## Adding a language feature

1. Define the grammar and semantics.
2. Update tokens/lexer if necessary.
3. Update the parser and AST.
4. Update semantic/type checking.
5. Add or extend the Sayanox IR.
6. Add lowering rules.
7. Update the active backend.
8. Add a small `.sa` example and regression coverage.
9. Update `docs/SYNTAX.md` and `docs/TUTORIAL.md` when user-visible syntax changes.
10. Verify with `make true-selfhost`.

## Standard library changes

Keep standard-library APIs small, composable, and documented. Prefer explicit return values for operations that can fail. Do not silently swallow file or conversion errors.

## Pull requests

A good pull request should include:

- a concise problem statement;
- the implementation and tests;
- documentation for public syntax or APIs;
- any bootstrap implications;
- known limitations.

Do not include generated binaries unless the repository explicitly requires them.
