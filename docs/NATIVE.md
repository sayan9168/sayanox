# Sayanox Native Compiler

```sh
make native
./selfhost/native_aot program.sa out && ./out
```

No clang for the user binary.

## Supported (native)

| Feature | Notes |
|---------|--------|
| hold/show/arith/%/compare | yes |
| when/while/make functions | yes |
| lists/fields | yes |
| **use "file.sa"** | modules inlined at compile time |
| **write_file("p","c")** | string literals, syscalls |
| **arg_count()** | from process argc |
| **run("cmd")** | fork/wait stub (child exits; full shell later) |
| GC heap region | reserved 256KB in binary |

## Still Stage-2 for full power

- `read_file` / `concat` returning live strings in expressions
- full `run` with `/bin/sh -c` execve
- concurrent GC / ownership
- all Stage-2 IR features

Native path keeps growing toward Stage-2 parity.
