# Status

## Native AOT (latest)
- hold/show/arith/compare/when/otherwise/while
- Runtime strings + **runtime concat** (`hold d = a + b`)
- Heap bump allocator for dynamic strings
- lists, fields, make/call, modules
- write_file / read_file / run(execve)
- len / ord / arg_count

## Still later
- Concurrent GC (bump allocator is linear only)
- Full Stage-2 IR without C host
- Package manager / LSP
