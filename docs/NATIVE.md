# Native backend (runtime x86_64)

```sh
make native
./selfhost/native_aot input.sa out_bin
./out_bin
```

No clang for the user binary.

## Supported (runtime machine code)

- `hold` / `show` / arithmetic / `when` / `while`
- `show "string"`
- **lists:** `hold xs = [1, 2, 3]`, `show xs[i]`, `show len(xs)`, `push(xs, v)`
- **struct fields:** `hold p.x = 3`, `show p.y` (slot fold)

## Full language

Modules, GC, all builtins, full struct types → **Stage-2 → C → clang**.
