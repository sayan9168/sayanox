# Native backend (step 2)

Linux **x86_64** ELF — **no clang** for the user program binary.

```sh
make native
./selfhost/native_aot examples/hello.sa hello_native
./hello_native
```

## Supported

- `hold name = <int>`
- `show <int>` / `show name`
- `when` / `otherwise`
- `while` (name or int condition)

AOT evaluates the subset, embeds printed text in the ELF, then `write`s it.

## Not yet

Strings, arithmetic, structs/lists, live machine-code loops (full ISA).
Full language: Stage-2 → C → clang.
