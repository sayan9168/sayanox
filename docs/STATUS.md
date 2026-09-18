# Status

## Native AOT (latest)
- hold/show/arith/compare/when/otherwise/while
- **Runtime strings**: `hold s = "hi"`, `hold t = "a" + "b"`, `show s`, `show len(s)`
- String tag `SAYA` (no clash with numbers)
- lists, fields, make/call, modules
- write_file / read_file / run(execve)
- len("str") / ord("c") / arg_count()

## Still later
- Concurrent GC / heap realloc for dynamic concat of runtime strings
- Full Stage-2 IR without C host
- Package manager / LSP
