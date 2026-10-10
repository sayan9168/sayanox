# Stage-2

> **Status (2026-10-10): legacy.** This page describes the older
> `selfhost/stage2` binary built by `selfhost/restore_stage2.sh`. No Makefile
> target builds or tests that binary, so it is not a verified state. The
> verified bootstrap is `seed-min -> gen1_min -> gen2 -> gen3 == gen4`
> (`make true-selfhost`, `make gen3`), and the "Stage-2" language features are
> tested by `make test-stage2` on gen2. See `docs/STATUS.md`, "What Stage-2
> means in this repository".


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
