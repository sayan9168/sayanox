# Hold RHS builtins (pure .sa gen1)

Gen1 lowers these function calls on the right-hand side of `hold`:

| Sayanox | Emitted C |
|---------|-----------|
| `arg_count()` | `sx_arg_count()` |
| `arg(i)` | `sx_arg(i)` |
| `read_file(path)` | `sx_read_file(path)` |
| `write_file(path, data)` | `sx_write_file(path, data)` |
| `concat(a, b)` | `sx_concat(a, b)` |
| `chr(n)` | `sx_chr(n)` |
| `str(n)` | `sx_str(n)` |
| `len(s)` | `sx_len(s)` |

## Test
```sh
./selfhost/gen1 selfhost/mini_builtin.sa /tmp/out.c
clang -o /tmp/out /tmp/out.c && /tmp/out a b
# 3 / A / hello! / 6 / 10 / done
```
