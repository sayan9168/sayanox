# Status

## Done
- Pure `.sa` compiler_min: hold/show/while/when/make/list/struct/string/field
- **Hold RHS builtins**: `arg_count` / `arg` / `read_file` / `write_file` / `concat` / `chr` / `str` / `len`
- Gen1 compiles programs using those builtins
- Self-host loop for subset (mini_in2 / field / builtins)

## Proven builtins
```
hold n = arg_count()     → sx_arg_count()
hold a = chr(65)         → sx_chr(65)
hold s = concat("a","b") → sx_concat(...)
hold ln = len(s)         → sx_len(s)
hold y = str(x)          → sx_str(x)
```

## Frontier
- Gen1 full self-compile of compiler_min.sa (scanner hang on large source)
- String indexing on hold RHS: `hold c = source[pos]`
- Uppercase identifiers
