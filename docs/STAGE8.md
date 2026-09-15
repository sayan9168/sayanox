# Stage-8 — Checked AST Boundary

Stage-8 introduces a bootstrap-safe checked-AST representation written in Sayanox.

## Goal

Move the compiler boundary from loosely connected parser/semantic demonstrations toward a validated intermediate representation that code generation can consume.

## Components

- `selfhost/checked_ast.sa` — checked node representation and validation.
- `selfhost/stage8_checked_ast.sh` — Stage-2 smoke test.

## Current checked node kinds

- `Number`
- `String`
- `Name`
- `List`
- `Assign`

Each node carries a semantic type and optional source-level name.

## Pipeline direction

```text
Source
  ↓
Lexer
  ↓
Parser / AST
  ↓
Semantic + Type Environment
  ↓
Checked AST  ← Stage-8
  ↓
IR / Lowering
  ↓
Code Generation
```

This is a real compiler boundary, but the existing implementation is intentionally a small bootstrap slice. It does not claim that the complete production compiler is self-hosted yet.

## Smoke test

```bash
bash selfhost/stage8_checked_ast.sh
```

Expected marker:

```text
Stage-8 checked AST OK
```

## Next target

Stage-9 should make the checked representation consume parser-produced structure and introduce a small Sayanox-owned IR/lowering layer before code generation.
