# Status

## Native AOT (latest)
- hold/show/arith/%/compare/when/otherwise/while
- lists, fields, make/call, modules (`use`)
- write_file / read_file / run(execve)
- **string concat** in show: `show "a" + "b" + "c"`
- **len("str")** and **ord("c")**
- arg_count()

## Examples
```sh
make native
./selfhost/native_aot examples/string_demo.sa /tmp/s && /tmp/s
```

## Still later
- runtime string values in variables
- concurrent GC
- full Stage-2 IR without C host
