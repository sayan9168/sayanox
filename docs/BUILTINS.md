# Stage-3 builtins (sxc_full)

| Builtin | Example | Emit |
|---------|---------|------|
| string hold | `hold s = "hi"` | `char *s = "hi";` |
| `concat` | `hold t = concat(a, b)` | `sx_concat(a,b)` |
| `len` | `hold n = len(s)` | `sx_len(s)` |
| index | `hold c = s[0]` | `sx_index(s,0)` |
| `read_file` | `hold d = read_file(path)` | `sx_read_file(path)` |
| `write_file` | `hold w = write_file(p, d)` | `sx_write_file(p,d)` |
| `arg_count` / `arg` | `hold n = arg_count()` | `sx_arg_count()` |
| `chr` / `str` | `hold s = chr(65)` | `sx_chr(65)` |

Build: `make selfhost-full`
