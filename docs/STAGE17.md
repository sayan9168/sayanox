# Stage 17 — Real AST → Canonical IR

Stage 17 moves the self-hosted compiler beyond an AST-only boundary.

## Pipeline

```text
Sayanox source
  ↓
source scanning
  ↓
AST arena
  ↓
AST-driven lowering
  ↓
canonical IR
```

The stage parses the source subset used by Stage 16, materializes the AST records, and then derives IR instructions from those records rather than maintaining a separate hard-coded instruction fixture.

## Current IR slice

The current subset lowers:

- numeric literals → `const`
- binary `+` → `add`
- assignment → `store`
- variable use → `load`
- `show` → `show`

For `hold answer = 40 + 2` followed by `show answer`, the generated instruction sequence is:

```text
const 40
const 2
add
store answer
load answer
show
```

## Run

```bash
bash selfhost/stage17_real_ir.sh
```

The script rebuilds the Stage-2 bootstrap, compiles the Sayanox stage program, executes it, and checks the Stage-17 success marker.

## Scope

This is an incremental compiler stage, not yet the complete Sayanox IR. Control flow, richer expressions, types, functions, modules, and a complete native backend remain future stages. Rust remains the bootstrap implementation while the self-hosted pipeline grows.
