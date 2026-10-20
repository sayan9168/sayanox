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
| `fixed-point` | `make gen3` | `bootstrap`'s `gen2` |
| `native` | `make native-test` | `bootstrap`'s `seed-min` and `gen2` |
| `audit` | tracked-artifact check, `make all-sayanox` inventory | — |

The only thing crossing a job boundary is a binary the `bootstrap` job built
with `make` from tracked sources. `.github/workflows/full-bootstrap.yml`
re-runs the whole chain in one job, in order, with no artifacts and no cache,
nightly and on demand; if that goes red while CI is green, the parallel shape
hid something and `ci.yml` is what needs fixing.

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
