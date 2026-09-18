# Sayanox Native Compiler

```sh
make native
./selfhost/native_aot program.sa out && ./out
```

## GC

```sa
hold a = "hello"
hold b = a + " world"
gc
show b
```

`gc` runs a stop-the-world mark-copy of live string variables into a high to-space.

## Strings / concat / packages / LSP

See STATUS.md, NATIVE_IR.md, LSP.md, and `./tools/sxpkg.sh`.
