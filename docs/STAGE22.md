# Sayanox Stage-22 — Functions, Parameters & Returns

Stage-22 extends the self-hosting compiler architecture with a function-signature and call-checking boundary.

## What this stage adds

- Function symbol lookup
- Function return-type metadata
- Parameter count validation
- Parameter type validation
- Undefined-function detection
- Call-expression return-type propagation
- Return-type compatibility checking

## Current supported model

The executable fixture models:

```sayanox
make add(a, b) {
    give a + b
}

hold result = add(40, 2)
show result
```

The Stage-22 checker represents `add` as a function with two `number` parameters and a `number` return type. It then validates a matching call site.

## Architecture

```text
Canonical AST
    ↓
Semantic Analyzer
    ↓
Function Signature Table
    ↓
Call Resolution
    ↓
Argument Count Check
    ↓
Argument Type Check
    ↓
Return Type Propagation
    ↓
Typed IR
```

## Important scope

This is an incremental compiler boundary, not yet a complete function implementation. The current fixture does not replace the existing parser, semantic engine, or IR pipeline. Function bodies, lexical scopes, closures, recursion, generic functions, and real AST-produced function signatures remain future work.

## Smoke test

Run:

```bash
bash selfhost/stage22_functions.sh
```

The test rebuilds the Stage-2 self-hosting runtime, compiles the Stage-22 source, and checks the expected success markers.

## Next direction

Stage-23 should connect function signatures to the real AST and typed IR so that function declarations and calls are produced by the compiler pipeline rather than represented by a standalone fixture.
