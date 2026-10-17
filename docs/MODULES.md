# Bootstrap modules: textual `use`, no namespaces or aliases

Decision confirmed 2026-10-16: module namespacing and import aliases are **not
planned for the bootstrap dialect**. The maintained seed-min, Gen2 and native
paths provide textual source splicing only. No module-identity feature is
implemented by this documentation update.

## Supported contract

```sayanox
use "stdlib/list_algo.sa"
hold values = [1, 2, 3]
show la_lower_bound(values, 2)
```

The quoted path selects source text to splice before ordinary compilation.
Definitions participate in the including program's ordinary name tables;
there is no separate module scope, export list, private visibility or qualified
symbol table. Keep explicit public prefixes (`la_`, `t_`, `nu_`, etc.).
Changing a path or copying a file does not rename its declarations or give them
a new identity. Repeated inclusion is not promised to be an idempotent import;
there is no import-once/module cache contract. Use nesting is capped at eight;
this is not a cyclic-module linker. Search-path details remain those of the
existing backend expanders; no new resolver is introduced here. In particular,
no general per-import directory stack, package version resolver or canonical
module identity is promised by this page.

`make test-use` retains its positive direct/nested splice and negative
missing/unquoted path checks. The existing stdlib gates also exercise real
`.sa` splices; the four bootstrap gates remain the integration contract.

## Unsupported — do not emulate with path rewriting

There is no `use "file.sa" as alias`, `alias::name`, namespace declaration,
qualified import, re-export or namespaced package resolution feature. A dotted
expression in supported code denotes a struct field chain, not a module member.
A path prefix is not a symbol prefix. For example, placing identical files at
`left/math.sa` and `right/math.sa` does not make two independent `math` scopes.

These forms are outside the bootstrap language contract, not deferred syntax
promised for a later bootstrap release. No alias parser or source rewrite was
added. Existing preprocessors can differ in diagnostics or ignore trailing
text on a `use` line; incidental parsing/ignored suffixes must **not** be treated
as working aliases. This documentation-only decision does not claim uniform
new refusal diagnostics for every alias-looking spelling.

A sound expansion would need canonical module identity, import scopes,
qualified symbol resolution across calls/types/fields/generic specializations,
collision/visibility rules and tests across all backends. A textual
find-and-replace or path rename cannot establish those properties. Such a
feature would be a separately designed language expansion, not a bootstrap
compatibility trick.

No pure-min splice implementation was changed. Gate logs for this decision
and the independent native IR-listing audit are in
[`gate-logs/2026-10-16-ir-modules/`](gate-logs/2026-10-16-ir-modules/).
