# Sayanox Stage-25 → Stage-27

These stages move function support from the earlier signature fixture toward compiler-owned function structure and lexical name resolution.

## Stage-25 — Function Declaration AST

Adds a concrete source-scanning boundary for:

```sayanox
make add(a, b) {
    give a + b
}
```

The compiler-owned arena records a function node, parameter nodes, and a body node.

## Stage-26 — Function Body AST

Extends the declaration with a real body shape:

```text
Function
  ├── Parameters
  └── Block
       └── Return
            └── Binary(+)
                 ├── Name(a)
                 └── Name(b)
```

This establishes the AST relationship needed by later lowering and semantic analysis.

## Stage-27 — Lexical Scopes

Adds a compiler-owned scope model with:

- Global and function scopes
- Parent-scope links
- Scope depth
- Symbol-to-scope ownership
- Nearest-scope name resolution
- Parameter visibility inside functions
- Parent-scope lookup
- Undefined-name rejection

## Smoke test

Run all three stages with:

```bash
bash selfhost/stage25_27.sh
```

The script rebuilds the Stage-2 self-hosting runtime and executes each stage.

## Scope note

These stages are still incremental self-hosting milestones. They do not yet replace `selfhost/parser.sa` with a complete recursive-descent parser, nor do they provide a full production semantic engine. The next work should connect these structures to the existing parser and then lower real function bodies into typed IR.
