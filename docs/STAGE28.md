# Sayanox Stage-28 — Parameters & Local Variables

Stage-28 adds a compiler-owned binding model for function parameters and local variables.

## What this stage adds

- Function-level symbol scope
- Parameter declarations
- Local-variable declarations
- Symbol kind metadata
- Symbol type metadata
- Scope ownership metadata
- Local/parameter name resolution
- Undefined-binding diagnostics

## Model

```text
Module scope
  └── Function: add
       ├── Parameter: a : number
       ├── Parameter: b : number
       └── Local: sum : number
```

The implementation keeps function parameters and locals in a compiler-owned symbol table. Resolution is restricted to the function scope, establishing the foundation for lexical-scope-aware semantic analysis.

## Important scope

This is the Stage-28 semantic boundary, not yet full parser integration. The next stages should connect these bindings to real function-body AST nodes and then lower parameter/local accesses into typed IR storage operations.

## Smoke test

```bash
bash selfhost/stage28_parameters_locals.sh
```

## Next direction

Stage-29 should make `give`/return semantics real: validate return expressions against the function return type, enforce missing-return rules where required, and connect return values to the function body AST.
