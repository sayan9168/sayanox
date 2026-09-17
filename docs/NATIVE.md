# Native backend

Linux **x86_64** ELF — **no clang** for the user binary.

## Build

```sh
make native
# clang -O2 -o selfhost/native_aot selfhost/native_aot.c
```

## Use

```sh
./selfhost/native_aot examples/hello.sa hello_native
./hello_native
```

## Step 2 support

| Feature | Status |
|---------|--------|
| `show <int>` | yes |
| `hold name = <int>` | yes (8 slots by name) |
| `show name` | yes |
| `when name/int { }` | yes |
| `otherwise { }` | yes |
| `while name { }` | yes (max 10000 iters) |

Evaluation is done at AOT time; the ELF embeds the printed output and `write`s it.

## Not yet

- Strings, structs, lists, arithmetic expressions
- True runtime machine code for loops (currently static eval)
- non-Linux / non-x86_64

Full-language path remains Stage-2 → C → clang.
