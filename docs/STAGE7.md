# Sayanox Stage-7 — Compiler Pipeline + Structured Diagnostics

Stage-7 moves the self-hosting architecture beyond isolated compiler passes.

## What is new

- `selfhost/stage7_pipeline.sa` — explicit compiler phase contract
- `selfhost/diagnostics.sa` — structured diagnostics storage and rendering
- `selfhost/stage7_pipeline.sh` — bootstrap-safe smoke test

## Pipeline contract

```text
Source
  ↓
Lexer
  ↓
Parser / AST
  ↓
Semantic + Type Environment
  ↓
Diagnostics
  ↓
Code Generation
```

The coordinator verifies that the phases are ordered correctly. The diagnostics
engine stores severity, compiler phase, message, hint, line, and column so later
compiler passes can report actionable errors without embedding presentation logic
inside every pass.

## Bootstrap boundary

Stage-7 remains bootstrap-safe. It is compiled through the existing Stage-2
seed and linked with the available system C compiler. Rust remains a bootstrap
implementation while the Sayanox-written compiler/tooling surface grows.

## Run

```bash
bash selfhost/stage7_pipeline.sh
```

Expected markers:

```text
Stage-7 pipeline contract OK
Stage-7 diagnostics OK
Stage-7 self-host pipeline smoke test passed
```

## Next target

The next major step is to replace the phase contract with a real shared AST and
semantic pipeline: parser nodes become typed values, the type environment is
populated from declarations and function signatures, diagnostics point back to
source spans, and code generation consumes the checked representation.
