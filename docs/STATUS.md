# Status

## Native AOT (this pass)
- hold/show/arith/%/compare/when/while/lists/fields/make/call
- `use "mod.sa"` modules
- `write_file` / **`read_file`** (print file to stdout)
- **`run("cmd")`** — writes script + fork + **execve `/bin/sh`**
- `arg_count()`

## Still later
- string concat / `read_file` as expression value
- concurrent GC
- full Stage-2 IR on native only
