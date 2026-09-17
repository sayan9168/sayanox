# Native backend (step 3)

Linux **x86_64** ELF — **no clang** for the user binary.

```sh
make native
./selfhost/native_aot examples/hello.sa hello_native
./hello_native
```

## Supported

| Feature | Example |
|---------|---------|
| `hold` / `show` ints | `hold x = 42` / `show x` |
| Arithmetic | `hold x = 10 + 32` / `show a * b` |
| `+ - * /` and `()` | `show (1+2)*3` |
| Strings | `show "Hello"` |
| `when` / `otherwise` / `while` | yes |

## Not yet

Structs, lists, true runtime ISA loops (still AOT-eval then embed).
Full language: Stage-2 → C → clang.
