# Self-host expression lowering

## Purpose

The next compiler boundary is explicit expression IR. The compiler must stop
passing source expressions such as `first_value + second_value` directly to
the C backend.

The intended lowering is:

```text
source
  ↓
expression parser
  ↓
identifier lookup
  ↓
CONST / LOAD
  ↓
ADD / SUB / MUL / DIV
  ↓
STORE / SHOW
```

For:

```sayanox
hold total_value = first_value + second_value
```

the canonical IR is:

```text
LOAD first_value
LOAD second_value
ADD
STORE total_value
```

## Why this matters

This makes the backend independent of source spelling and gives the language
its own compiler representation. It also creates the boundary needed for
later function calls, return values, optimization, and a native backend.

## Current status

The repository now contains an explicit expression-IR contract and a
multi-character expression regression source. The existing Stage-3 compiler
entry still has a compatibility path that can preserve raw expressions; that
path should be replaced by this lowering boundary before the native backend
milestone.

## Next compiler work

1. Build expression nodes from the parser output.
2. Resolve every identifier through the scoped symbol table.
3. Emit typed arithmetic IR.
4. Reject undefined identifiers before backend emission.
5. Make C emission consume only IR values.
6. Add function-call expressions and return-value IR.
