# Sayanox Native Compiler

Linux **x86_64** AOT — **no clang** for user `.sa` binaries.

```sh
make native
./selfhost/native_aot program.sa out_bin
./out_bin
```

## Subset

- hold / show / `+ - * / %`
- `== != < > <= >=`
- when / otherwise / while
- strings, lists, fields
- **make name(a,b) { ... }** and **name(1,2)**

Full language still uses Stage-2.
