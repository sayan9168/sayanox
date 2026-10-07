# Feature matrix

This page describes the **maintained, tested bootstrap path**, not every
prototype in `examples/` or `selfhost/`. The detailed behavior and backend
limits are maintained in [`STATUS.md`](STATUS.md); reproduce them with
`make true-selfhost`, `make gen3`, and `make native-test`.

| Feature | Example | seed-min | gen2 | native AOT |
|---------|---------|----------|------|------------|
| Bindings and output | `hold x = 42`; `show x` | yes | yes | yes |
| Branches and loops | `when x > 0 {}`; `while x < 3 {}`; `else` / `otherwise` | yes | yes | yes |
| Numeric expressions | `+ - * / %`, precedence, parentheses, integer/fractional literals | yes | yes | yes |
| `%` by zero | `show 7 % zero` | diagnostic | diagnostic | diagnostic |
| Functions | `make f(x) { give x + 1 }`, recursion | yes | yes | yes (numeric functions; see limits) |
| Lists | `[10, 20]`, `xs[0]`, `len(xs)`, `push(xs, v)` | yes | yes | yes |
| Structs | named fields, strings, nested values and field access | yes | yes | yes |
| Strings | literals, `concat`, `len`, `chr`, `string_eq`, indexing | yes | yes | yes |
| File and argument builtins | `read_file`, `write_file`, `arg`, `arg_count` | yes | yes | yes |
| Modules | `use "file.sa"` textual splice | yes | yes | yes (bounded nesting) |

All rows mean the tested language subset; backend-specific errors and
extensions are listed in [`STATUS.md`](STATUS.md). In particular, the native
backend is x86-64 Linux only and does not support every construct accepted by
the C-generating compilers.

## Not yet part of the maintained shared subset

These are roadmap items or older experimental syntax, not promises of the
current seed-min/gen2/native toolchain:

- namespaced exports/imports and versioned module resolution;
- namespaced exports/imports and versioned module resolution;
- additional string helpers such as `contains`, `starts_with`, `ends_with`,
  `repeat`, and `substr`;
- a complete standard library and richer static types;
- automatic heap ownership/collection across all backends (gen2-compiled
  programs have a mark & sweep collector; native AOT still bump-allocates);
- portable native code generation and remote package publishing/hosting.

Some of these appear in old examples or compiler-stage experiments. Their
presence in the repository does not mean they are wired into the maintained
bootstrap path. Contributions should add a regression test to each affected
backend and update `STATUS.md` before they are described as supported.
