# native_src

`c00.part` … `c19.part` assemble into `native_aot.c`:

```sh
cat selfhost/native_src/c*.part > selfhost/native_aot.c
clang -O2 -o selfhost/native_aot selfhost/native_aot.c
```

Or: `make native`
