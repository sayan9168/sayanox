# Step 2 — Actual compiler wiring

Step 2 moves variable and function handling from informal examples toward explicit compiler-owned structures.

## Scope and symbols

`selfhost/symbols.sa` owns lexical symbol state:

- identifier -> slot mapping
- lexical depth
- declaration allocation
- reverse lookup from the newest visible declaration
- explicit scope enter/leave operations

The backend must consume slots rather than rediscover variable names from source text.

## IR boundary

`selfhost/function_ir.sa` defines explicit operations for:

- `function`
- `param`
- `load_local`
- `store_local`
- `call`
- `return`

This gives the lowering pipeline a stable representation for functions before native instruction selection.

## Required compiler flow

```text
source
  -> lexer
  -> parser
  -> AST
  -> semantic/symbol resolution
  -> local slot allocation
  -> LOAD_LOCAL / STORE_LOCAL
  -> CALL / RETURN
  -> Sayanox IR
  -> lowering
  -> backend
```

## Important boundary

The current repository still has a Stage-2 C bootstrap seed. These files make the compiler representation language-owned, but they do not falsely claim that the native backend already exists.

The next implementation work is to replace the remaining demonstration IR records with parser-produced records and then make the C backend consume those records generically.

## Verification rule

A Step-2 feature is considered production-ready only when the same `.sa` source can be parsed and lowered without hard-coded variable names, with nested lexical scopes and function calls covered by regression tests.
