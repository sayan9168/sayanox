# Sayanox Native Compiler

```sh
make native
./selfhost/native_aot program.sa out && ./out
```

## Features

| Feature | Example |
|---------|---------|
| hold/show/arith | `hold x = 1 + 2 % 3` |
| compare/when/while | `when x == 1 { ... }` |
| functions | `make f(a) { show a }` |
| modules | `use "lib.sa"` |
| write_file | `write_file("/tmp/a.txt", "hi\n")` |
| **read_file** | `read_file("/tmp/a.txt")` |
| **run** | `run("echo hi")` |
| arg_count | `show arg_count()` |
