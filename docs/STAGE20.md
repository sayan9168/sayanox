# Stage 20 — Semantic Analyzer

Stage 20 adds the semantic-analysis boundary to the self-hosted Sayanox compiler pipeline.

## Pipeline

Sayanox source
  ↓
AST
  ↓
Symbol declaration
  ↓
Name resolution
  ↓
Type validation
  ↓
Checked semantic program

## Current checks

- declaration tracking
- duplicate declaration detection
- lexical symbol lookup
- undefined-name detection
- numeric type validation
- assignment type compatibility
- expression operand validation
- semantic diagnostic counters

## Current subset

The stage validates the canonical AST for:

```text
hold answer = 40 + 2
show answer
```

The symbol environment records `answer` as a `number`. The binary expression requires numeric operands, assignment compatibility is checked, and the later `show answer` resolves the name through the symbol table.

## Run

```bash
bash selfhost/stage20_semantic.sh
```

The smoke script rebuilds the Stage-2 bootstrap, compiles the Stage-20 Sayanox program, executes it, and checks the semantic success marker.

## Scope

This is the first concrete semantic-analysis slice, not the complete type checker. Nested scopes, booleans, strings, lists, functions, user-defined types, control-flow joins, and richer diagnostics remain future work. Rust remains the bootstrap implementation while the self-hosted compiler expands.
