# Stage 18 — IR to Native Backend

Stage 18 establishes the first executable backend boundary for the Sayanox self-hosting pipeline.

## Pipeline

```text
Sayanox source
  -> real source parsing
  -> AST arena
  -> canonical IR
  -> native backend
  -> C source
  -> native executable
```

The backend consumes a canonical six-instruction IR slice:

```text
const 40
const 2
add
store answer
load answer
show
```

It deterministically emits C source and the smoke test compiles that generated source with a system C compiler and verifies the native program prints `42`.

## Scope

This is a real IR-driven backend boundary, but it is intentionally a small supported subset. The backend is not yet a complete machine-code generator and still uses C as the native bootstrap target.

## Run

```bash
bash selfhost/stage18_native_backend.sh
```

## Next

Stage 19 should expand the backend around the real IR schema: typed values, comparisons, branches, loops, function calls, and structured diagnostics. After that, the project can begin replacing the C bootstrap boundary with a Sayanox-owned lower-level backend while keeping the Rust bootstrap compiler available for compatibility.
