# Stage 14 — Parser → AST Boundary

Stage 14 introduces the next compiler boundary: source syntax is represented as a deterministic AST contract before lowering to IR.

## Current slice

The fixture models:

```text
hold answer = 40 + 2
show answer
```

The contract records a program, assignment, binary expression, numeric literals, show operation, and name reference.

## Validation

Run:

```bash
bash selfhost/stage14_parser_bridge.sh
```

The smoke test rebuilds the Stage-2 bootstrap, compiles the Stage-14 Sayanox source, and validates the parser/AST boundary markers.

## Architecture direction

```text
Sayanox source
    ↓
Lexer
    ↓
Parser
    ↓
AST
    ↓
Semantic/type checking
    ↓
Canonical IR
    ↓
C backend
    ↓
Native executable
```

This is still a staged bootstrap contract rather than a claim of complete self-hosting. The Rust implementation remains the production bootstrap while the Sayanox implementation expands toward compiler self-hosting.

## Next

Stage 15 should connect the existing parser implementation to real AST node construction, then feed those nodes into checked AST and IR lowering without fixture-only node arrays.
