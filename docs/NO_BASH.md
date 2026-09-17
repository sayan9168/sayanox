# Bash removed from the core path

## What runs the toolchain now

| Piece | Language |
|-------|----------|
| Stage-2 compiler | C (`stage2_template.c`) |
| CLI logic | **Sayanox** (`selfhost/sx.sa`) |
| One-time builders | C (`build_stage2.c`, `sx_launcher.c`) |
| Format / pkg helpers | **Sayanox** (`tools/sxfmt.sa`, `tools/sxpkg.sa`) |

## Commands

```bash
make stage2
make sx
./selfhost/sx_bin examples/hello.sa /tmp/hello 1
```

Or:

```bash
clang -O2 -o selfhost/build_stage2 selfhost/build_stage2.c && ./selfhost/build_stage2
./selfhost/stage2 selfhost/sx.sa selfhost/sx_cli.c
clang -O2 -o selfhost/sx_bin selfhost/sx_cli.c
./selfhost/sx_bin examples/hello.sa out 1
```

Legacy `*.sh` files may remain as optional wrappers; **core logic is Sayanox + C**.

## New builtins

- `run("cmd")` — shell command (links with system linker via clang)
- `arg_count()` / `arg(i)` — CLI arguments
