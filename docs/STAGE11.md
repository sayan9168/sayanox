# Stage-11 — Control-Flow IR Pipeline

Stage-11 expands the Sayanox-owned compiler IR from a linear instruction list into a control-flow-aware representation.

## What is new

- Explicit basic blocks: `entry`, `then`, `else`, `exit`
- Temporary value IDs
- Typed IR instructions
- Arithmetic lowering (`add`)
- Storage operations (`load`, `store`)
- Conditional branch representation
- Unconditional jumps between blocks
- Deterministic structural validation
- Bootstrap-safe smoke test

## Pipeline

```text
Source
  -> Lexer
  -> Parser / AST
  -> Semantic + Type Environment
  -> Checked AST
  -> Lowering
  -> Stage-11 Control-Flow IR
  -> Backend / Codegen
```

## Current scope

This stage is an explicit compiler-architecture slice, not a claim that the entire parser already lowers automatically into this IR. The next integration work is to connect real parsed expressions/statements to the IR builder and then add an executable backend.

## Run

```bash
bash selfhost/stage11_ir.sh
```

Expected final marker:

```text
Stage-11 IR pipeline smoke test passed
```

## Next target

Stage-12 should connect real Sayanox AST nodes to this IR, add function/control-flow lowering, and establish an IR-to-C backend boundary so the generated program can be executed end-to-end.
