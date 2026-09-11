# Self-Hosting Sayanox — Phase 6

## New language builtins (bootstrap compiler)

| Builtin | Meaning |
|---------|---------|
| `read_file(path)` | Read entire file as string |
| `write_file(path, data)` | Write string to file |
| `concat(a, b)` | String concat |
| `len(x)` | Length |
| `push(list, v)` | Dynamic list grow |

## Example

```sa
hold data = read_file("input.sa")
write_file("out.c", data)
```

See `examples/file_io.sa`.

## Self-host driver

`compiler.sa` still runs the in-memory pipeline and can call `write_file`.

## Run

```bash
cargo build --release
./target/release/sayanox examples/file_io.sa -o fio.c && gcc fio.c -o fio && ./fio
./target/release/sayanox selfhost/compiler.sa -o c6.c && gcc c6.c -o c6 && ./c6
```

## Roadmap

| Phase | Status |
|-------|--------|
| 5 Unified driver | ✅ |
| 6 File I/O + richer builtins | ✅ |
| 7 True bootstrap (compiler compiles .sa files from disk end-to-end) | 🚧 |
