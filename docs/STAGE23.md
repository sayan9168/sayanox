# Stage-23 — Real Function AST → Typed IR Pipeline

Stage-23 moves function support beyond the Stage-22 signature-table fixture. It establishes a compiler-owned AST-to-IR boundary for a small function subset.

## Supported slice

```sayanox
make add(a, b) {
    give a + b
}

hold result = add(40, 2)
show result
```

The stage models:

- Function declaration nodes
- Parameter nodes
- Return nodes
- Binary expression nodes
- Function call nodes
- Numeric literal arguments
- Assignment and name-use nodes
- Function registration and lookup
- Parameter-count validation
- Call lowering into typed IR operations
- Return, call, store, load, and show operations

## Pipeline

```text
Sayanox AST
    ↓
Function registration
    ↓
Function lookup
    ↓
Call validation
    ↓
Return-expression validation
    ↓
Typed IR emission
```

## Files

- `selfhost/stage23_function_pipeline.sa`
- `selfhost/stage23_function_pipeline.sh`

## Smoke test

Run:

```bash
bash selfhost/stage23_function_pipeline.sh
```

The script rebuilds the Stage-2 bootstrap compiler, compiles the Stage-23 source, and checks the expected pipeline markers.

## Scope

This is an incremental self-hosting milestone, not yet a complete general-purpose function compiler. The AST used here is a canonical Stage-23 function subset. The next stages should connect the real parser output, lexical source locations, local function scopes, recursive calls, and a general function-capable IR/backend.

Rust remains the bootstrap implementation at this point; Stage-23 does not claim full self-hosting.
