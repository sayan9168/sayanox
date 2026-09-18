# Sayanox Native Compiler

```sh
make native
./selfhost/native_aot program.sa out && ./out
```

## Features

| Feature | Example |
|---------|---------|
| hold/show/arith | `hold x = 1 + 2 % 3` |
| when/otherwise | `when x == 1 { ... } otherwise { ... }` |
| while | `while x < 10 { ... }` |
| string concat | `show "hi" + " " + "there"` |
| len / ord | `show len("abcd")` / `show ord("A")` |
| functions | `make f(a) { show a }` |
| modules | `use "lib.sa"` |
| write_file | `write_file("/tmp/a.txt", "hi\n")` |
| read_file | `read_file("/tmp/a.txt")` |
| run | `run("echo hi")` |
| arg_count | `show arg_count()` |
