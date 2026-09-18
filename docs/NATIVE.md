# Sayanox Native Compiler

```sh
make native
./selfhost/native_aot program.sa out && ./out
```

## Strings

```sa
hold s = "hello"
show s
hold t = "say" + "anox"
show t
show len(s)
```

Strings are tagged pool offsets (prefix SAYA). Numbers print as decimal; tagged values print as text.

## Other features
hold/show, arith, when/otherwise, while, lists, fields, make/call, use, write_file, read_file, run, arg_count, len, ord
