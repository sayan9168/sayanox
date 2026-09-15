# Stage-9 — Sayanox Intermediate Representation

Stage-9 introduces a Sayanox-owned intermediate representation (IR) between the checked source representation and later lowering/code generation.

## IR operations

- `const` — materialize a typed constant
- `load` — load a named value
- `store` — store a typed value
- `show` — represent output of a typed value

The current implementation is a small bootstrap-safe IR contract. It validates opcode/type pairs before the compiler grows expression lowering and control-flow blocks.

## Pipeline

```text
Source → Lexer → Parser/AST → Semantic/Type Environment → Checked AST → IR → Lowering → Codegen
```

## Smoke test

```bash
bash selfhost/stage9_ir.sh
```

Expected marker:

```text
Stage-9 IR OK
Stage-9 IR smoke test passed
```

## Next

Stage-10 should introduce real lowering from checked nodes into IR, followed by basic expression and control-flow instructions. Rust remains the bootstrap host while more compiler ownership moves into Sayanox.
