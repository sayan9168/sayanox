# Stage 16 — Real Source → AST

Stage 16 removes the hard-coded AST fixture used by the earlier parser bridge and introduces a small, deterministic parser path that derives AST records from actual Sayanox source text.

## Current supported slice

```text
hold answer = 40 + 2
show answer
```

The implementation reads the source, scans keywords/identifiers/numbers/operators, and materializes compiler-owned parallel AST arrays:

- `node_kind`
- `node_value`
- `node_left`
- `node_right`
- `node_count`

The resulting node structure is:

```text
Program
├── Assign(answer)
│   └── Binary(+)
│       ├── Number(40)
│       └── Number(2)
└── Show
    └── Name(answer)
```

## Verification

Run:

```bash
bash selfhost/stage16_real_ast.sh
```

The smoke test rebuilds the Stage-2 bootstrap, compiles `stage16_real_ast.sa`, runs it, and checks the real-parser/AST markers.

## Why this stage matters

Stage 14 established a parser/AST contract and Stage 15 established semantic checking over a fixed node arena. Stage 16 makes the AST source-derived rather than fixture-derived. This is the foundation for the next step: lowering real AST nodes into canonical Sayanox IR.

## Scope boundary

This is intentionally a small vertical slice, not yet the complete Sayanox grammar. The existing lexer/parser foundations remain in the repository and the Rust implementation remains the bootstrap compiler. Future stages will expand expressions, declarations, control flow, functions, types, diagnostics, and eventually self-host the full compiler.
