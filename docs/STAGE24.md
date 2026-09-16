# Sayanox Stage-24 — Real Function Source Pipeline

Stage-24 moves function analysis beyond the standalone Stage-23 signature fixture. The compiler now scans an actual Sayanox source string and discovers a function declaration and a call site from that source.

## Source subset

```sayanox
make add(a, b) {
    give a + b
}

hold result = add(40, 2)
show result
```

## What this stage adds

- Real source scanning for `make` declarations
- Function-name extraction
- Parameter counting from the declaration
- Compiler-owned function signature registration
- Duplicate-function detection
- Real call-site discovery
- Function lookup from the discovered call
- Argument-count validation
- Return-type metadata propagation

## Pipeline

```text
Sayanox source
    ↓
Source scanner
    ↓
Function declaration
    ↓
Function signature table
    ↓
Call-site discovery
    ↓
Function lookup
    ↓
Argument validation
    ↓
Return-type metadata
```

## Important scope

This is a real source-reading boundary, but it is still intentionally narrow. It does not yet reuse the complete `selfhost/parser.sa` recursive parser, build a general function AST, parse typed parameters, analyze function bodies, or lower arbitrary function calls into executable IR.

The existing Rust compiler remains the bootstrap implementation. Stage-24 is part of the incremental Sayanox self-hosting path.

## Smoke test

Run:

```bash
bash selfhost/stage24_real_functions.sh
```

The script rebuilds the Stage-2 self-hosting runtime, compiles the Stage-24 source, and checks the expected pipeline markers.

## Next direction

Stage-25 should connect the real function source parser to the compiler-owned AST and typed IR, including function-body expressions, parameter bindings, call arguments, and return values.
