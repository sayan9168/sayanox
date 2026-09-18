# Status

## Done (this pass)
- Native AOT restored: hold/show/arith/%/compare/when/while/lists/fields/make/call
- Modules: `use "file.sa"`
- `write_file`, `arg_count`, `run` (fork/wait stub)
- Stage-2 path still works for full language
- Python: none in repo

## Bootstrap seed (not the language)
- Minimal C: `native_aot` / Stage-2 — required once so `.sa` can run

## Still open
- Full `run` with execve `/bin/sh -c`
- `read_file` / string concat on native path
- Concurrent GC
- Replace seed over time with Sayanox-written emitter
