# Sayanox Stage-5 — Semantic Ownership Shift

Stage-5 moves the first useful semantic-analysis work into Sayanox itself.

## What is now Sayanox

- Primitive type inference for `hold` declarations.
- Symbol-table storage using Sayanox lists.
- Name lookup and assignment compatibility checks.
- Semantic diagnostics emitted by a Sayanox program.
- A reproducible Stage-5 verification script.

The implementation lives in `selfhost/semantic.sa` and is executed through the existing Stage-2 host. The semantic algorithm itself is Sayanox source, not Rust.

## Run

```bash
./selfhost/restore_stage2.sh
./selfhost/stage2 selfhost/semantic.sa selfhost/stage5_semantic.c
clang -O2 -o selfhost/stage5_semantic selfhost/stage5_semantic.c
./selfhost/stage5_semantic
```

Or use:

```bash
bash selfhost/stage5_semantic.sh
```

## Architecture direction

```text
Rust compiler
    │
    │ bootstrap / host implementation
    ▼
Stage-2 host
    │
    ▼
Sayanox lexer + parser + AST + semantic passes + codegen
    │
    ▼
Sayanox-generated toolchain
```

Stage-5 is intentionally incremental: the Rust compiler remains available as a trusted bootstrap implementation while more compiler intelligence is transferred into Sayanox. The next target is a Sayanox-written semantic/type system integrated with the real compiler pipeline, followed by a Sayanox-written package/toolchain layer.
