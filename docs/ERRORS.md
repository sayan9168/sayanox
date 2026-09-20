# Compiler errors

Sayanox diagnostics must be actionable and English-only.

## Required diagnostic shape

Every lexer/parser/type/module error should identify:

1. source file;
2. line and column;
3. the relevant source line;
4. a caret (`^`) under the offending token;
5. a concise explanation;
6. a useful hint when one is available.

Example:

```text
stage2: examples/bad.sa:4:13: error: cannot add num and str
    hold value = count + name
                ^^^^^
hint: convert both operands to the same kind
```

## Module errors

Relative imports are resolved from the importing file:

```sa
use "mod_lib.sa"
```

A missing module reports the importing file and resolved path. Cyclic imports report the complete import chain instead of recursing indefinitely.

Both `use "path.sa"` and `import "path.sa"` are accepted by the Stage-2 module preprocessor.

## Type errors

The lightweight kinds are `num`, `str`, `list`, and `struct`. Type errors should name both the operation and the conflicting kinds.

## Parser progress

Malformed input must never be silently skipped. Any recovery path must either consume the offending token and emit a diagnostic or terminate with a diagnostic. This prevents parser loops caused by a zero-progress `pos` update.

## Current implementation boundary

The self-hosted lexer already records source locations and emits structured error records. Stage-2 diagnostics are being aligned with the same file/line/column/snippet/caret contract.
