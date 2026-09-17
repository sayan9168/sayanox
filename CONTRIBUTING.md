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

The tiny Stage-2 host is bootstrap infrastructure, not the long-term language implementation.

## Local workflow

```sh
make stage2
bash selfhost/bootstrap_production.sh
./selfhost/sx examples/hello.sa --run
```

For changes to compiler stages, also inspect the generated output and run the repository CI checks.

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
10. Verify the bootstrap path from Stage-2.

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
