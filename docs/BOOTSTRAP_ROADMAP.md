# Sayanox Bootstrap Roadmap

## Purpose

This roadmap tracks the next step in reducing Sayanox's dependence on the Stage-2 C compiler bootstrap.

The goal is **not** to remove C/Clang in one jump. The immediate goal is to move more compiler lowering into Sayanox source while keeping one deliberately small C bootstrap for producing the first Stage-2 binary.

## Current bootstrap boundary

Today the repository still has a C Stage-2 implementation. `make stage2` / `selfhost/restore_stage2.sh` produces the Stage-2 binary, and that binary is used to run Sayanox compiler sources.

The important architectural boundary is:

```text
small C bootstrap
      |
      v
 Stage-2 binary
      |
      +--> selfhost/codegen.sa
      +--> selfhost/compiler.sa
      +--> other Sayanox compiler sources
      |
      v
  generated native output
```

This means the C implementation is being treated as a bootstrap mechanism, not as the long-term home of the Sayanox compiler.

## Roadmap

### Stage A — Keep the bootstrap tiny

**Status: active**

- Keep one minimal C Stage-2 bootstrap path.
- Keep `make stage2` and `selfhost/restore_stage2.sh` working.
- Do not add new compiler features to the C bootstrap unless they are required to preserve the bootstrap boundary.
- Keep the bootstrap implementation isolated under `selfhost/stage2_src/` and the Stage-2 template.

### Stage B — Port Stage-2 lowering into Sayanox

**Status: active — first arithmetic boundary implemented**

Move more of the lowering logic out of the Stage-2 C implementation and into:

- `selfhost/codegen.sa`
- `selfhost/compiler.sa`
- shared Sayanox compiler/IR sources where appropriate

The first targets should be small, composable lowering operations:

1. constants and primitive values — **implemented as a Sayanox-owned lowering boundary**
2. local variable load/store — next
3. arithmetic expressions — **first binary-expression lowering boundary added in `compiler.sa`**
4. comparisons — planned
5. basic control-flow lowering — planned
6. function calls and returns — planned
7. structured values already represented by the self-host pipeline — planned

The current arithmetic step lowers simple numeric binary expressions into a canonical backend expression before C emission. It is intentionally not a native CPU backend and does not yet replace the existing Stage-2 path.

Each larger port should have a Sayanox-side representation and a small smoke example before the corresponding C bootstrap logic is considered unnecessary.

### Stage C — Make the Sayanox lowering pipeline authoritative

**Status: planned**

The pipeline should increasingly look like:

```text
Sayanox source
  -> lexer
  -> parser
  -> semantic/type checks
  -> Sayanox IR
  -> lowering
  -> backend interface
```

At this point, `compiler.sa` should coordinate the pipeline and `codegen.sa` should perform substantially more lowering itself instead of depending on Stage-2-specific behavior.

The numbered historical Stage scripts are not part of this path. Use the supported bootstrap commands documented in the main README and `selfhost/README.md`.

### Stage D — Introduce a real native backend

**Status: planned — outline only**

A real native backend is required before C/Clang can be removed from the compiler bootstrap path.

The backend will eventually need to cover, at minimum:

- target-independent lowered IR
- target-specific instruction selection
- registers and/or a target-aware virtual register model
- stack-frame and calling-convention handling
- branches and control flow
- integer and floating-point operations
- memory addressing
- function prologues/epilogues
- object/executable emission
- platform ABI details
- diagnostics for unsupported target operations

The first native backend should be deliberately narrow: one target, a small instruction subset, and deterministic tests. It should grow from the existing IR rather than becoming a second compiler architecture.

### Stage E — Bootstrap without C

**Status: future**

Only after the native backend can compile the required compiler subset should the project attempt a native bootstrap chain such as:

```text
existing tiny C bootstrap
        |
        v
  Stage-2 Sayanox compiler
        |
        v
 native backend
        |
        v
  native Sayanox compiler
        |
        v
  self-hosted rebuild
```

The C bootstrap can then become a historical/bootstrap artifact rather than a required build dependency.

## What is intentionally NOT claimed

Full removal of C/Clang is **not complete**.

Sayanox does **not** yet have a complete native CPU backend capable of replacing the current C emission/bootstrap path. Implementing that backend is a substantial compiler milestone and is intentionally left as a future stage in this roadmap.

Likewise, porting more lowering into `codegen.sa` does not by itself make Sayanox self-hosting. The compiler must still be able to produce correct native output through a backend that does not depend on C/Clang.

## Completion criteria

A stage is considered complete only when:

- the Sayanox implementation is checked into the repository;
- a reproducible smoke test exists;
- the supported bootstrap path still works;
- documentation describes the new boundary accurately;
- no claim is made that C/Clang has been removed until a native backend actually replaces it.

## Guiding principle

**Reduce the bootstrap boundary incrementally. Do not replace a working compiler path with an unverified all-at-once rewrite.**
