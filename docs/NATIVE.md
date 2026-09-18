# Sayanox Native Compiler

```sh
make native
./selfhost/native_aot program.sa out && ./out
```

## Strings

```sa
hold a = "hello"
hold b = "world"
hold c = a + " " + b
show c
show len(c)
```

Compile-time literal concat and **runtime** string concat both work. Dynamic results live in a heap bump region after the string pool.

## Other
arith, when/otherwise, while, lists, fields, make/call, use, write_file, read_file, run, arg_count, len, ord
