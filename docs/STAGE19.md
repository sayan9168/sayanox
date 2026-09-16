# Stage 19 — Typed Control-Flow IR

Stage 19 extends the canonical Sayanox IR contract with explicit value types and control-flow blocks.

## Pipeline boundary

Sayanox source
  ↓
AST
  ↓
semantic/type information
  ↓
**typed canonical IR**
  ↓
native backend

## IR additions

The stage introduces a small `sx-ir-0.2` contract containing:

- typed numeric values
- boolean comparison results
- explicit `cmp_gt`
- conditional `branch`
- named control-flow blocks: `entry`, `then`, `else`, `exit`
- `store`, `load`, and `show` operations
- deterministic instruction arrays suitable for a later native backend

The fixture models the shape of:

```text
if 10 > 3 {
    answer = 10
} otherwise {
    answer = 3
}
show answer
```

## Run

```bash
bash selfhost/stage19_typed_control_ir.sh
```

The script rebuilds the Stage-2 bootstrap, compiles the Stage-19 Sayanox program, executes it, and checks the success markers.

## Scope

Stage 19 defines and validates the typed/control-flow IR boundary. It is not yet a complete parser, semantic checker, optimizer, or general control-flow lowering engine. Those are subsequent stages.
