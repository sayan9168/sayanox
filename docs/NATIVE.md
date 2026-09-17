# Native backend (MVP)

Linux **x86_64** ELF writer — **does not call clang** to produce the program binary.

## Build

```sh
clang -O2 -o selfhost/native_aot selfhost/native_aot.c
# or: make native
```

## Use

```sh
./selfhost/native_aot examples/hello.sa hello_native
./hello_native
# 42
```

## Supported (MVP)

- One or more `show <integer>` lines
- Output is a static ELF that `write`s the numbers and exits

## Not yet

- `hold`, loops, strings, structs, lists
- non-x86_64 / non-Linux
- Full Stage-2 parity

This is the first step toward “no clang for user programs.” The Stage-2 → C path remains the full-language path.
