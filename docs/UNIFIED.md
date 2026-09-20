# Unified native + selfhost backend

One driver: **`selfhost/sx`**

```sh
make unified          # native_aot + sxc + sx

./selfhost/sx --backend=native -o out examples/hello.sa
./out                 # 42

./selfhost/sx --backend=c -o out selfhost/sxc_test_in.sa
./out                 # 0 1 2 42 99 done

./selfhost/sx --backend=auto -o out examples/fib_native.sa
```

| Backend | Tool | Output |
|---------|------|--------|
| `native` | `native_aot` | x86-64 ELF directly |
| `c` | `sxc` + `clang` | C then binary |
| `auto` | native if present, else c | |

```sh
make sx FILE=examples/hello.sa BACKEND=native OUT=/tmp/h
make test
```
