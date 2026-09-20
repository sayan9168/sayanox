# Native AOT status

## Current implementation

Sayanox currently has a self-contained Linux x86-64 native AOT seed in `selfhost/native_aot.c`.

The path is:

```text
.sa -> native parser / expression IR -> x86-64 machine-code emission -> ELF executable
```

The emitted program does not require a generated C file or a second compiler.

The maintained native source covers the core subset including `hold`, `show`, integer expressions, arithmetic, `when` / `otherwise`, and `while`. The split source is under `selfhost/native_src/`.

## Cranelift status

Cranelift is **not the active native backend**. The repository's current direction removed the Cranelift dependency to keep the bootstrap path small.

The active native backend emits Linux x86-64 machine code directly. `docs/CRANELIFT.md` is historical/status information, not a build requirement.

## Current IR boundary

`selfhost/native_aot.c` has a lightweight internal representation through `parse_prim`, `parse_term`, `parse_expr`, `estmt`, and `eblk`. It is not a public SSA or Cranelift-style IR.

The two compilation paths are:

- **Native:** `.sa -> internal expression/statement representation -> x86-64 ELF`
- **C fallback:** `.sa -> generated .c -> clang -> executable`

No generated `.c` is required by the native backend.

## Build and run

Build the native compiler seed once:

```sh
make native
```

Compile and run a native program:

```sh
./selfhost/native_aot examples/native_hello.sa /tmp/sayanox_native_hello
/tmp/sayanox_native_hello
```

Expected output:

```text
42
```

`make bootstrap-native` remains available as a convenience target.

## Unified driver

`selfhost/sx_driver.c` supports explicit backend selection:

```sh
./selfhost/sx --backend=native -o out examples/native_hello.sa
./out

./selfhost/sx --backend=c -o out examples/native_hello.sa
./out
```

`--backend=c` remains the compatibility fallback for programs outside the native subset. `--backend=auto` prefers the native compiler when available and otherwise uses the C route.

## Limitations

The native backend is a subset compiler, not a replacement for the complete Stage-2 compiler. Native support must not be assumed for every `.sa` construct.

When native lowering cannot safely support a program, use:

```sh
./selfhost/sx --backend=c -o out program.sa
```

The native backend is currently Linux x86-64 specific.

## Bootstrap impact

The native compiler is separate from the pure `gen1` subset path. Native AOT changes must not alter the `.sa -> gen1 -> subset` bootstrap chain.

The C source is used only to build the native compiler executable itself:

```text
clang -> native_aot -> .sa -> ELF
```

User programs compiled by `native_aot` do not pass through clang.
