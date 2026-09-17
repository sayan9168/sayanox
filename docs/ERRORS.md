# Errors

Stage-2 diagnostics are English and include path + line when available:

```text
stage2: path.sa:12: error: expected name after hold
stage2: path.sa:3: error: cannot reassign 'x' to a different type
```

## Tips

1. Run `./selfhost/sx file.sa --run` — compile errors print before link.
2. Check unmatched `{` / `}` and missing `=` after `hold`.
3. String vs number: use quotes for strings; bare digits for numbers.

## Roadmap

- Source snippet + caret under the token
- Suggestions (e.g. “did you mean show?”)
