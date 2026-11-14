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

The checked-in native Sayanox anchor and generated `sx` entry are the explicit
bootstrap trust inputs; the preferred path is `./sx target true-selfhost`
(seed-min). Generated C and the host C compiler remain explicit C-output
dependencies, not a maintained C seed.

## Local workflow

```sh
./sx doctor
./sx verify-entry
./sx target true-selfhost
./sx target gen3
./sx target native-test
```

For changes to compiler stages, also inspect the generated output and run the repository CI checks.

## Continuous integration

`.github/workflows/ci.yml` runs the guarded Sayanox acceptance chain on a clean
Linux checkout. The maintained implementation and test logic stay in Sayanox;
Python/Node/Ruby/Perl and network download tools are poisoned in the guarded
jobs, while the explicit host C compiler and POSIX process boundaries remain
visible dependencies. `./sx ci` runs the complete local chain: migration audit,
doctor, CI shape, true-selfhost, gen3 fixed point, native acceptance and the
published-language full gate. A focused target passing is not a substitute for
that complete chain, and historical green runs do not accept new edits.

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
10. Verify with `./sx target true-selfhost` and the focused regression gate.

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
