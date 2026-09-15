# Stage 13 — Real Source-to-IR Bridge

Stage 13 moves the self-hosting effort from a pure IR fixture toward an executable compiler boundary driven by an actual `.sa` source file.

## Pipeline

```text
stage13_program.sa
        ↓
source loading
        ↓
source-to-IR bridge
        ↓
typed canonical IR
        ↓
C backend
        ↓
native executable
```

## Source

The fixture contains:

```sayanox
hold answer = 40 + 2
show answer
```

The bridge produces the following conceptual IR sequence:

```text
const 40      → t0
const 2       → t1
add t0,t1     → t2
store answer  ← t2
load answer   → t2
show answer   ← t2
```

## Validation

Run:

```bash
bash selfhost/stage13_source_ir.sh
```

Expected marker:

```text
Stage-13 source-to-IR OK
Stage-13 source-to-IR smoke test passed
```

## Important boundary

This stage is intentionally conservative. The source file is real Sayanox, but the bridge still recognizes a constrained source contract rather than the complete parser/AST output. The next milestone is to replace this contract with structured parser and semantic records, then lower arbitrary supported expressions and statements.

Rust remains the bootstrap implementation while compiler ownership continues moving into Sayanox.
