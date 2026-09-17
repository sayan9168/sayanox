# Stage-2

Stage-2 is the **full** Sayanox `.sa` → C compiler (bootstrap host).

## Build

```bash
chmod +x selfhost/restore_stage2.sh
./selfhost/restore_stage2.sh
```

Produces `selfhost/stage2`.

## Use

```bash
./selfhost/stage2 input.sa output.c
clang -o prog output.c && ./prog

# wrapper
./selfhost/sx input.sa --run
```

## Language features

| Feature | Support |
|---------|--------|
| `show` / `hold` | yes |
| `when` / `otherwise` / `while` | yes |
| `make` / `give` | yes |
| `struct` | yes |
| strings + `show name` | yes |
| lists | yes |
| arithmetic / compare / modulo | yes |
| `use` modules | yes |
| stdlib (`concat`, `len`, `read_file`, …) | yes |

## Smoke tests

```bash
./selfhost/sx examples/hello.sa --run
./selfhost/sx examples/countdown.sa --run
./selfhost/sx examples/greet.sa --run
```

## Role in self-host

Stage-2 lowers Sayanox-written compilers (`sayanoxc.sa`, `compiler.sa`) to native binaries. See `docs/FULL_SELFHOST.md`.
