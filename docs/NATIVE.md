# Native backend

Runtime **x86_64** (no clang for user binary).

```sh
make native
./selfhost/native_aot examples/hello.sa out && ./out
```

## Supported

- hold / show / arithmetic / when / while / strings
- lists: `hold xs = [1,2,3]`, `xs[i]`, `len(xs)`, `push(xs,v)`
- fields: `hold p.x = 3`, `show p.y`

## Full language

Still Stage-2 → C → clang for modules/GC/all builtins.

Hex parts under `selfhost/native_src/h*.hex` assemble via `make native`.
