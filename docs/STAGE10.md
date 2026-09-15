# Stage 10 — Checked AST Lowering and Canonical IR

Stage 10 introduces the next compiler boundary in Sayanox source: a checked semantic representation is lowered into a small canonical intermediate representation (IR).

## Architecture

```text
Sayanox source
    ↓
Lexer / Parser
    ↓
Semantic + Type Environment
    ↓
Checked AST
    ↓
Stage-10 Lowering
    ↓
Canonical Sayanox IR
    ↓
Future optimization / backend lowering
    ↓
Code generation
```

## IR v0.1

The initial instruction vocabulary is intentionally small:

- `const`
- `load`
- `store`
- `show`
- `add`
- `jump`
- `branch`

Each instruction carries an opcode, operand, and value type. This gives later optimization and backend work a stable boundary without pretending the full compiler is already self-hosted.

## Files

- `selfhost/lowering.sa` — checked-AST to canonical IR lowering slice
- `selfhost/ir_builder.sa` — IR construction and validation boundary
- `selfhost/stage10_lowering.sh` — bootstrap smoke test

## Run

```bash
bash selfhost/stage10_lowering.sh
```

Expected markers:

```text
Stage-10 lowering OK
Stage-10 lowering smoke test passed
```

## Next direction

Stage 11 should connect real parser/semantic output to this IR instead of using fixture records, then introduce basic blocks, labels, temporaries, expression lowering, and deterministic IR validation.

Rust remains the bootstrap host while more compiler functionality moves into Sayanox.
