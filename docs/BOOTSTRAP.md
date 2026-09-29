# Sayanox bootstrap

The subset self-host path is intentionally small.

## Bootstrap chain

```text
C compiler (clang)
    |
    v
sxc_full.c
    |
    v
gen1
    |
    +--> subset .sa programs
    |
    +--> compiler_min.sa -> gen2
                       |
                       v
                      gen2
                       |
                       +--> subset .sa programs
```

## What still needs clang

A C compiler is still required to create the first executable bootstrap compiler when no trusted bootstrap compiler is already available.

The normal seed path is Stage-2:

```sh
clang -O2 -o selfhost/build_stage2 selfhost/build_stage2.c
./selfhost/build_stage2
./selfhost/stage2 selfhost/compiler_min.sa selfhost/gen1.c
clang -O2 -o selfhost/gen1 selfhost/gen1.c
```

The reason is bootstrapping: a machine needs at least one executable compiler before it can execute the Sayanox compiler.

After gen1 exists, the subset path does not need sxc_full.c or Stage-2 for source compilation.

## Preferred subset path

If selfhost/gen1 already exists:

```sh
./selfhost/gen1 selfhost/program.sa selfhost/program.c
clang -O2 -o selfhost/program selfhost/program.c
./selfhost/program
```

For the next compiler generation:

```sh
./selfhost/gen1 selfhost/compiler_min.sa selfhost/gen2.c
clang -O2 -o selfhost/gen2 selfhost/gen2.c
```

Then prefer gen2 for subsequent subset compilation:

```sh
./selfhost/gen2 selfhost/program.sa selfhost/program.c
```

The generated application is still C in the current subset backend, so clang is needed to turn generated C into a native application. This is separate from the compiler bootstrap dependency.

## Bootstrap fallback

gen1 is the preferred compiler once it exists. Stage-2 is only a bootstrap seed. sxc_full.c is retained only as a last-resort fallback where that seed is still available.

A known-good generated gen1.c may be frozen as a last-resort bootstrap artifact when reproducible bootstrapping requires it. It is not the normal subset compilation path.

Do not regenerate gen1 from sxc_full.c merely to compile ordinary subset programs.

## Supported entry points

Use:

```sh
make subset
```

or, when selfhost/gen1 already exists:

```sh
make subset-existing
```

`make complete` remains an alias for the supported subset smoke test for compatibility.

The pure pipeline proof is:

```sh
make gen2          # === GEN2-PARTIAL ===
```

`selfhost/bootstrap_gen2.sh` uses the C seed exactly once (to build gen1 from
`selfhost/compiler_min.sa`), then gen1 builds the pure compiler `boot` from
`selfhost/compiler_boot.sa`, `boot` compiles pure-min programs, and `boot`
recompiling its own source gives a byte-identical `boot2.c`. Nothing is
copied. It is *partial*: gen1 still cannot compile `compiler_min.sa` itself —
the exact limits are in `docs/STATUS.md`.

## Source of truth

The compiler implementation for the subset is in Sayanox source under selfhost/.

The C seed exists only to solve the initial bootstrap problem. The long-term goal is to eliminate the C seed from the normal development path.
