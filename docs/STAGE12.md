# Stage 12 — Native Backend Boundary

Stage 12 crosses an important compiler boundary: Sayanox-owned compiler logic emits deterministic C source that can be compiled into a native executable.

## Pipeline

```text
Sayanox source
    ↓
self-hosted frontend
    ↓
checked AST
    ↓
Sayanox IR
    ↓
control-flow lowering
    ↓
Sayanox-owned C backend boundary
    ↓
C compiler
    ↓
native executable
```

## Current slice

`selfhost/backend_c.sa` emits a small typed arithmetic program:

```text
40 + 2 → answer → show answer
```

The generated C is compiled with a system C compiler and must print `42`.

## Validation

Run:

```bash
bash selfhost/stage12_backend.sh
```

The smoke test validates:

- Stage-2 can compile the Sayanox backend source.
- The backend emits C source.
- C compilation succeeds with strict warnings.
- The resulting native executable prints exactly `42`.

## Why this is a major milestone

Earlier stages validated isolated frontend, checked-AST, IR, and control-flow concepts. Stage 12 establishes an executable path from Sayanox-owned compiler code to a native artifact.

This is still a deliberately small backend slice. It is not yet a complete self-hosted compiler. Rust remains the bootstrap implementation while Sayanox progressively takes ownership of frontend, IR, backend, tooling, and runtime responsibilities.

## Next target

Stage 13 should replace the hard-coded backend program with real IR records produced from parsed and semantically checked `.sa` input, then add:

- real expression lowering
- variables and assignments
- comparisons
- conditional branches
- loops
- function calls
- multiple functions
- deterministic backend validation
- executable integration tests
